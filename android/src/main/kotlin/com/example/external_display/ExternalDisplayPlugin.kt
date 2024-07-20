package com.example.external_display

import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.FrameLayout
import android.view.ViewGroup
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject

import android.content.ContentValues.TAG
import android.util.Log

class ExternalDisplayPlugin: FlutterPlugin, MethodCallHandler, StreamHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var methodChannel : MethodChannel
  private lateinit var eventChannel : EventChannel
  private lateinit var context: Context
  private lateinit var displayManager : DisplayManager
  private lateinit var events : EventChannel.EventSink
  private val displayListener = object : DisplayManager.DisplayListener {
    override fun onDisplayAdded(displayId: Int) {
      if (displayManager.displays.size > 1) {
        val displayId = displayManager.displays.last().displayId
        val display = displayManager.getDisplay(displayId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          result.success(mapOf("width" to display.mode.physicalWidth.toDouble(), "height" to display.mode.physicalHeight.toDouble()))
        } else {
          result.success(mapOf("width" to display.width.toDouble(), "height" to display.height.toDouble()))
        }
      }
    }
    override fun onDisplayRemoved(displayId: Int) {
      events.success(false)
    }
    override fun onDisplayChanged(p0: Int) {}
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

  override fun onDetachedFromActivity() {}
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    context = binding.activity
    displayManager = context?.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager;
  }
  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method == "connect") {
      if (displayManager.displays.size > 1 && context != null) {
        val displayId = displayManager.displays.last().displayId;
        val args = JSONObject("${call.arguments}")
        var routeName: String = args.getString("routeName")
        if (routeName == "null") {
          routeName = "externalView"
        }
        val display = displayManager.getDisplay(displayId)
        if (display != null) {
          val flutterEngine : FlutterEngine
          if (FlutterEngineCache.getInstance().get(routeName) == null) {
            flutterEngine = FlutterEngine(context!!)
            flutterEngine.navigationChannel.setInitialRoute(routeName)

            FlutterInjector.instance().flutterLoader().startInitialization(context!!)
            val appBundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
            val entrypoint = DartExecutor.DartEntrypoint(appBundlePath, "externalDisplayMain")
            flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
            flutterEngine.lifecycleChannel.appIsResumed()

            FlutterEngineCache.getInstance().put(routeName, flutterEngine)
          } else {
            flutterEngine = FlutterEngineCache.getInstance().get(routeName) as FlutterEngine
          }

          val flutterView = FlutterView(context)
          flutterView.attachToFlutterEngine(flutterEngine)

          val view = FrameLayout(context)
          view.addView(flutterView, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
          ))

          val presentation = Presentation(context, display)
          presentation.setContentView(view)
          presentation.show()

          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            result.success(mapOf("width" to display.mode.physicalWidth.toDouble(), "height" to display.mode.physicalHeight.toDouble()))
          } else {
            result.success(mapOf("width" to display.width.toDouble(), "height" to display.height.toDouble()))
          }
          return
        }
        result.success(false)
      }
    } else {
      result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink)
  {
    events = eventSink
    if (displayManager.displays.size > 1) {
      val displayId = displayManager.displays.last().displayId
      val display = displayManager.getDisplay(displayId)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        result.success(mapOf("width" to display.mode.physicalWidth.toDouble(), "height" to display.mode.physicalHeight.toDouble()))
      } else {
        result.success(mapOf("width" to display.width.toDouble(), "height" to display.height.toDouble()))
      }
    }
    displayManager.registerDisplayListener(displayListener, Handler(Looper.getMainLooper()))
  }

  override fun onCancel(arguments: Any?)
  {
    displayManager.unregisterDisplayListener(displayListener)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
  }
}
