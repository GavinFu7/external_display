package com.gavinfu.external_display

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.util.Log
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

private const val TAG = "ExternalDisplayPlugin"

class ExternalDisplayPlugin: FlutterPlugin, MethodCallHandler, StreamHandler, ActivityAware {
  private val readyWaiters = ReadyWaiters()
  var mainViewEvents : EventChannel.EventSink? = null
  private val externalViewEvents = mutableMapOf<String, EventChannel.EventSink>()

  private lateinit var methodChannel : MethodChannel
  private lateinit var eventChannel : EventChannel
  private lateinit var context: Context
  private lateinit var displayManager : DisplayManager
  private val activePresentations = mutableMapOf<String, SessionPresentation>()
  private val activeEngines = mutableMapOf<String, FlutterEngine>()
  private val activeFlutterViews = mutableMapOf<String, FlutterView>()
  private val routeDisplayIds = mutableMapOf<String, Int>()
  private val routeActivities = mutableMapOf<String, Activity>()
  private val routeResolutions = mutableMapOf<String, Map<String, Double>>()

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
      if (routesToRemove.isNotEmpty()) {
        sendSessionEnded()
      } else {
        mainViewEvents?.success(isPlugged())
      }
    }

    override fun onDisplayChanged(p0: Int) {}
  }

  override fun onDetachedFromActivityForConfigChanges() {
    releaseActivity()
  }
  override fun onDetachedFromActivity() {
    releaseActivity()
  }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    context = binding.activity
  }
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    context = binding.activity
  }

  /** Ends the sessions shown through the leaving Activity; later ones use the application. */
  private fun releaseActivity() {
    val activity = context as? Activity ?: return
    context = activity.applicationContext
    val routes = routeActivities.filterValues { it === activity }.keys.toList()
    for (routeName in routes) {
      tearDownSession(routeName)
    }
    if (routes.isNotEmpty()) {
      sendSessionEnded()
    }
  }

  /** A session ended without disconnect/connect asking: report unplugged, then the plug state. */
  private fun sendSessionEnded() {
    mainViewEvents?.success(false)
    mainViewEvents?.success(isPlugged())
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    displayManager = flutterPluginBinding.applicationContext.getSystemService(Context.DISPLAY_SERVICE) as
              DisplayManager
    displayManager.registerDisplayListener(displayListener, Handler(Looper.getMainLooper()))

    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "monitorStateListener")
    eventChannel.setStreamHandler(this)

    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "displayController")
    methodChannel.setMethodCallHandler(this)
  }

  /**
   * Dismiss presentation, detach view, and destroy engine for [routeName]. Never throws: the
   * route's entries are removed first, and every release step runs even if an earlier one fails.
   */
  private fun tearDownSession(routeName: String) {
    val flutterView = activeFlutterViews.remove(routeName)
    val presentation = activePresentations.remove(routeName)
    val engine = activeEngines.remove(routeName)
    routeDisplayIds.remove(routeName)
    routeActivities.remove(routeName)
    routeResolutions.remove(routeName)
    externalViewEvents.remove(routeName)

    if (flutterView != null) {
      releaseStep(routeName, "detach view") { flutterView.detachFromFlutterEngine() }
    }
    if (presentation != null) {
      releaseStep(routeName, "dismiss") {
        // Our own dismissal must not come back through the dismiss listener.
        presentation.setOnDismissListener(null)
        presentation.dismiss()
      }
      releaseStep(routeName, "release presentation") { presentation.releaseIfNotShown() }
    }
    if (engine != null) {
      releaseStep(routeName, "detach platform views") { engine.platformViewsController.detach() }
      releaseStep(routeName, "detach platform views 2") { engine.platformViewsController2.detach() }
      releaseStep(routeName, "destroy engine") { engine.destroy() }
      FlutterEngineCache.getInstance().remove(routeName)
    }
  }

  /** Runs one release step of [routeName]'s teardown; a failure is logged, not thrown. */
  private inline fun releaseStep(routeName: String, step: String, action: () -> Unit) {
    try {
      action()
    } catch (e: Exception) {
      Log.e(TAG, "teardown of route $routeName: $step failed", e)
    }
  }

  private fun tearDownAllSessions() {
    val routeNames = (activePresentations.keys + activeEngines.keys).toSet()
    for (routeName in routeNames) {
      tearDownSession(routeName)
    }
  }

  private fun presentationDisplayIds(): List<Int> {
    return displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
      .map { it.displayId }
  }

  private fun allDisplayIds(): List<Int> {
    return displayManager.displays.map { it.displayId }
  }

  private fun isPlugged(): Boolean {
    return DisplaySelector.isPlugged(presentationDisplayIds(), allDisplayIds())
  }

  /** Physical pixel size of the display's current mode. */
  private fun physicalSize(display: Display): Pair<Int, Int> {
    return display.mode.physicalWidth to display.mode.physicalHeight
  }

  /** Android closed [presentation] itself, not [tearDownSession]: end its session. */
  private fun onPresentationDismissed(routeName: String, presentation: Presentation) {
    if (activePresentations[routeName] !== presentation) {
      return
    }
    tearDownSession(routeName)
    sendSessionEnded()
  }

  private fun hasSession(routeName: String): Boolean {
    return activePresentations.containsKey(routeName) || activeEngines.containsKey(routeName)
  }

  private fun connect(call: MethodCall, result: MethodChannel.Result) {
    if (!isPlugged()) {
      result.success(false)
      return
    }
    val routeName = MethodCallArgs.routeName(call.arguments)
    val displayId = DisplaySelector.choose(
      MethodCallArgs.targetScreen(call.arguments),
      presentationDisplayIds(),
      allDisplayIds()
    )
    val display: Display? = displayId?.let { displayManager.getDisplay(it) }
    if (display == null) {
      result.success(false)
      return
    }

    val running = routeResolutions[routeName]
    if (running != null &&
      activePresentations[routeName]?.isShowing == true &&
      routeDisplayIds[routeName] == display.displayId
    ) {
      // Connecting again to the same display keeps the running session.
      result.success(running)
      return
    }

    // Reconnect / repeated connect must not stack Presentations or leak engines.
    tearDownSession(routeName)

    val (width, height) = physicalSize(display)
    val resolution: Map<String, Double> = mapOf(
      "width" to width.toDouble(),
      "height" to height.toDouble()
    )

    try {
      // Views use the Presentation's display context; the engine needs only the application.
      val presentation = SessionPresentation(context, display)
      activePresentations[routeName] = presentation
      routeDisplayIds[routeName] = display.displayId
      (context as? Activity)?.let { routeActivities[routeName] = it }
      // Back must not close the second screen; any other dismissal ends the session.
      presentation.setCancelable(false)
      presentation.setOnDismissListener { onPresentationDismissed(routeName, presentation) }

      val flutterEngine = FlutterEngine(context.applicationContext)
      activeEngines[routeName] = flutterEngine

      flutterEngine.navigationChannel.setInitialRoute(routeName)

      FlutterInjector.instance().flutterLoader().startInitialization(context.applicationContext)
      val appBundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
      val entrypoint = DartExecutor.DartEntrypoint(appBundlePath, "externalDisplayMain")
      flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
      flutterEngine.lifecycleChannel.appIsResumed()

      // Only the delegator installs the platform-views channel handler (Flutter 3.38+).
      flutterEngine.platformViewsControllerDelegator.attach(
        presentation.context,
        flutterEngine.renderer,
        flutterEngine.dartExecutor
      )

      FlutterEngineCache.getInstance().put(routeName, flutterEngine)

      val receiveParameters = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "receiveParametersListener"
      )
      receiveParameters.setStreamHandler(ExternalViewHandler(this, routeName, flutterEngine))
      val sendParameters = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "sendParameters"
      )
      sendParameters.setMethodCallHandler(ExternalViewHandler(this, routeName, flutterEngine))

      val flutterView = FlutterView(presentation.context)
      flutterView.attachToFlutterEngine(flutterEngine)
      activeFlutterViews[routeName] = flutterView

      val view = FrameLayout(presentation.context)
      view.addView(
        flutterView,
        FrameLayout.LayoutParams(
          ViewGroup.LayoutParams.MATCH_PARENT,
          ViewGroup.LayoutParams.MATCH_PARENT
        )
      )

      presentation.setContentView(view)
      presentation.show()
    } catch (e: Exception) {
      // For example InvalidDisplayException or BadTokenException from show().
      Log.e(TAG, "connect failed for route $routeName on display ${display.displayId}", e)
      tearDownSession(routeName)
      result.success(false)
      return
    }
    routeResolutions[routeName] = resolution
    result.success(resolution)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "getScreen" -> {
        val screens = displayManager.displays.map { display ->
          val (width, height) = physicalSize(display)
          "${display.displayId}. ${display.name} [${width}x${height}]"
        }.toList()
        result.success(screens)
      }

      "connect" -> {
        connect(call, result)
      }

      "disconnect" -> {
        val routeName = MethodCallArgs.routeName(call.arguments)
        val existed = hasSession(routeName)
        tearDownSession(routeName)
        result.success(existed)
      }

      "waitingTransferParametersReady" -> {
        if (externalViewEvents.isNotEmpty()) {
          result.success(true)
        } else {
          // Answered once: true when a view subscribes, false after this call's own timeout
          // or when the plugin detaches first.
          val handler = Handler(Looper.getMainLooper())
          lateinit var sendFail: Runnable
          val token = readyWaiters.add(
            {
              handler.removeCallbacks(sendFail)
              result.success(true)
            },
            {
              handler.removeCallbacks(sendFail)
              result.success(false)
            }
          )
          sendFail = Runnable {
            if (readyWaiters.remove(token)) {
              result.success(false)
            }
          }
          handler.postDelayed(sendFail, 10000)
        }
      }

      "sendParameters" -> {
        val sinks = externalViewEvents.values.toList()
        for (sink in sinks) {
          sink.success(call.arguments)
        }
        result.success(sinks.isNotEmpty())
      }

      else -> {
        result.success(false)
      }
    }
  }

  override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
    mainViewEvents = eventSink
    if (isPlugged()) {
      eventSink.success(true)
    }
  }

  override fun onCancel(arguments: Any?) {
    mainViewEvents = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    displayManager.unregisterDisplayListener(displayListener)
    mainViewEvents = null
    // Answer pending waiters now instead of replying to a destroyed engine later.
    readyWaiters.cancelAll()
    tearDownAllSessions()
    eventChannel.setStreamHandler(null)
    methodChannel.setMethodCallHandler(null)
  }

  /** The external view of [routeName] subscribed; ignored once [engine]'s session has ended. */
  internal fun onExternalViewListen(
    routeName: String,
    engine: FlutterEngine,
    eventSink: EventChannel.EventSink
  ) {
    if (activeEngines[routeName] !== engine) {
      return
    }
    externalViewEvents[routeName] = eventSink
    readyWaiters.notifyReady()
  }

  /** The external view of [routeName] unsubscribed; leaves a newer session's sink alone. */
  internal fun onExternalViewCancel(routeName: String, engine: FlutterEngine) {
    if (activeEngines[routeName] === engine) {
      externalViewEvents.remove(routeName)
    }
  }
}

class ExternalViewHandler(
  plugin: ExternalDisplayPlugin,
  private val routeName: String,
  private val engine: FlutterEngine
) : MethodCallHandler, StreamHandler {
  private val externalDisplayPlugin = plugin

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    externalDisplayPlugin.mainViewEvents?.success(call.arguments)
    result.success(externalDisplayPlugin.mainViewEvents != null)
  }

  override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
    externalDisplayPlugin.onExternalViewListen(routeName, engine, eventSink)
  }

  override fun onCancel(arguments: Any?) {
    externalDisplayPlugin.onExternalViewCancel(routeName, engine)
  }
}

/**
 * A Presentation that can undo its onStart() when show() throws: show() runs onStart(), which
 * registers a display listener for the process lifetime, before adding the window, and
 * dismiss() skips onStop() for a dialog that never became showing.
 */
private class SessionPresentation(outerContext: Context, display: Display) :
  Presentation(outerContext, display) {
  private var started = false

  override fun onStart() {
    super.onStart()
    started = true
  }

  override fun onStop() {
    started = false
    super.onStop()
  }

  /** Runs the missing onStop() once if onStart() ran but the window never showed. */
  fun releaseIfNotShown() {
    if (started && !isShowing) {
      onStop()
    }
  }
}
