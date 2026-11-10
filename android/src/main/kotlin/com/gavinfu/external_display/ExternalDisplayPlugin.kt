package com.gavinfu.external_display

import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class ExternalDisplayPlugin: FlutterPlugin, MethodCallHandler, StreamHandler, ActivityAware {
  var connectReturn : (() -> Unit)? = null
  var mainViewEvents : EventChannel.EventSink? = null
  var externalViewEvents : EventChannel.EventSink? = null

  private lateinit var methodChannel : MethodChannel
  private lateinit var eventChannel : EventChannel
  private lateinit var context: Context
  private lateinit var displayManager : DisplayManager
  private val activePresentations = mutableMapOf<String, Presentation>()
  private val activeEngines = mutableMapOf<String, FlutterEngine>()
  private val activeFlutterViews = mutableMapOf<String, FlutterView>()
  private val routeDisplayIds = mutableMapOf<String, Int>()

  private val displayListener = object : DisplayManager.DisplayListener {
    override fun onDisplayAdded(displayId: Int) {
      mainViewEvents?.success(true)
    }

    override fun onDisplayRemoved(displayId: Int) {
      val routesToRemove = routeDisplayIds
        .filter { it.value == displayId }
        .keys
        .toList()
      for (routeName in routesToRemove) {
        tearDownSession(routeName)
      }
      mainViewEvents?.success(displayManager.displays.size > 1)
    }

    override fun onDisplayChanged(p0: Int) {}
  }

  override fun onDetachedFromActivityForConfigChanges() {}
  override fun onDetachedFromActivity() {}
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    context = binding.activity
    displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    displayManager = flutterPluginBinding.applicationContext.getSystemService(Context.DISPLAY_SERVICE) as
              DisplayManager

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "monitorStateListener")
    eventChannel.setStreamHandler(this)

    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "displayController")
    methodChannel.setMethodCallHandler(this)
  }

  /** Dismiss presentation, detach view, and destroy engine for [routeName]. */
  private fun tearDownSession(routeName: String) {
    activeFlutterViews.remove(routeName)?.detachFromFlutterEngine()

    activePresentations.remove(routeName)?.dismiss()
    routeDisplayIds.remove(routeName)

    val engine = activeEngines.remove(routeName)
    if (engine != null) {
      engine.destroy()
      FlutterEngineCache.getInstance().remove(routeName)
    }

    externalViewEvents = null
    connectReturn = null
  }

  private fun tearDownAllSessions() {
    val routeNames = (activePresentations.keys + activeEngines.keys).toSet()
    for (routeName in routeNames) {
      tearDownSession(routeName)
    }
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "getScreen" -> {
        val screens = displayManager.displays.map { display ->
          "${display.displayId}. ${display.name} [${display.width}x${display.height}]"
        }.toList()
        result.success(screens)
      }

      "connect" -> {
        if (displayManager.displays.size > 1) {
          val routeName = MethodCallArgs.routeName(call.arguments)
          var displayId = MethodCallArgs.targetScreen(call.arguments)
          var display: Display? = null
          if (displayId > 0) {
            display = displayManager.getDisplay(displayId)
          }
          if (display == null && displayManager.displays.isNotEmpty()) {
            display = displayManager.displays.last()
            displayId = display.displayId
          }
          if (display != null) {
            // Reconnect / repeated connect must not stack Presentations or leak engines.
            tearDownSession(routeName)

            val flutterEngine = FlutterEngine(context)

            flutterEngine.navigationChannel.setInitialRoute(routeName)

            FlutterInjector.instance().flutterLoader().startInitialization(context)
            val appBundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
            val entrypoint = DartExecutor.DartEntrypoint(appBundlePath, "externalDisplayMain")
            flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
            flutterEngine.lifecycleChannel.appIsResumed()

            flutterEngine.platformViewsController.attach(
              context,
              flutterEngine.renderer,
              flutterEngine.dartExecutor
            )

            FlutterEngineCache.getInstance().put(routeName, flutterEngine)
            activeEngines[routeName] = flutterEngine

            val resolution: Map<String, Double> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
              mapOf(
                "width" to display.mode.physicalWidth.toDouble(),
                "height" to display.mode.physicalHeight.toDouble()
              )
            } else {
              mapOf(
                "width" to display.width.toDouble(),
                "height" to display.height.toDouble()
              )
            }

            val receiveParameters = EventChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "receiveParametersListener"
            )
            receiveParameters.setStreamHandler(ExternalViewHandler(this))
            val sendParameters = MethodChannel(
              flutterEngine.dartExecutor.binaryMessenger,
              "sendParameters"
            )
            sendParameters.setMethodCallHandler(ExternalViewHandler(this))

            val flutterView = FlutterView(context)
            flutterView.attachToFlutterEngine(flutterEngine)
            activeFlutterViews[routeName] = flutterView

            val view = FrameLayout(context)
            view.addView(
              flutterView,
              FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
              )
            )

            val presentation = Presentation(context, display)
            presentation.setContentView(view)
            presentation.show()
            activePresentations[routeName] = presentation
            routeDisplayIds[routeName] = display.displayId

            result.success(resolution)
            return
          }
          result.success(false)
        } else {
          result.success(false)
        }
      }

      "disconnect" -> {
        val routeName = MethodCallArgs.routeName(call.arguments)
        tearDownSession(routeName)
        result.success(true)
      }

      "waitingTransferParametersReady" -> {
        val handler = Handler(Looper.getMainLooper())
        val sendFail = Runnable {
          result.success(false)
          connectReturn = null
        }

        fun returnResolution() {
          handler.removeCallbacks(sendFail)
          result.success(true)
          connectReturn = null
        }
        connectReturn = ::returnResolution

        if (externalViewEvents != null) {
          connectReturn?.invoke()
        } else {
          handler.postDelayed(sendFail, 10000)
        }
      }

      "sendParameters" -> {
        if (externalViewEvents != null) {
          externalViewEvents?.success(call.arguments)
          result.success(true)
        } else {
          result.success(false)
        }
      }

      else -> {
        result.success(false)
      }
    }
  }

  override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
    mainViewEvents = eventSink
    if (displayManager.displays.size > 1) {
      eventSink.success(true)
    }
    displayManager.registerDisplayListener(displayListener, Handler(Looper.getMainLooper()))
  }

  override fun onCancel(arguments: Any?) {
    displayManager.unregisterDisplayListener(displayListener)
    mainViewEvents = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    tearDownAllSessions()
    eventChannel.setStreamHandler(null)
    methodChannel.setMethodCallHandler(null)
  }
}

class ExternalViewHandler(plugin: ExternalDisplayPlugin) : MethodCallHandler, StreamHandler {
  private val externalDisplayPlugin = plugin

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    externalDisplayPlugin.mainViewEvents?.success(call.arguments)
    result.success(true)
  }

  override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
    externalDisplayPlugin.externalViewEvents = eventSink
    externalDisplayPlugin.connectReturn?.invoke()
  }

  override fun onCancel(arguments: Any?) {
    externalDisplayPlugin.externalViewEvents = null
  }
}
