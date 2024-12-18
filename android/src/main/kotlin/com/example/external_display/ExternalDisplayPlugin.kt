package com.example.external_display

import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.FrameLayout
import android.view.ViewGroup
import android.view.Display
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
  var connectReturn : (() -> Unit)? = null
  var mainViewEvents : EventChannel.EventSink? = null
  var externalViewEvents : EventChannel.EventSink? = null

  private lateinit var methodChannel : MethodChannel
  private lateinit var eventChannel : EventChannel
  private lateinit var context: Context
  private lateinit var displayManager : DisplayManager

  // 處理監控插入和拔出外部顯示器
  private val displayListener = object : DisplayManager.DisplayListener {
    // 插入外部顯示器
    override fun onDisplayAdded(displayId: Int) {
      mainViewEvents?.success(true)
    }
    // 拔出外部顯示器
    override fun onDisplayRemoved(displayId: Int) {
      mainViewEvents?.success(false)
    }
    override fun onDisplayChanged(p0: Int) {}
  }

  // 初始化
  override fun onDetachedFromActivityForConfigChanges() {}
  override fun onDetachedFromActivity() {}
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    context = binding.activity
    displayManager = context?.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager;
  }
  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    displayManager = flutterPluginBinding.applicationContext.getSystemService(Context.DISPLAY_SERVICE) as
              DisplayManager

    // 建立 Flutter EventChannel
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "monitorStateListener")
    eventChannel.setStreamHandler(this)

    // 建立 Flutter MethodChannel
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "displayController")
    methodChannel.setMethodCallHandler(this)
  }

  // 接收主頁面的命令和參數
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      // 連結外部顯示器
      "connect" -> {
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

            val resolution:Map<String, Double>
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
              resolution = mapOf("width" to display.mode.physicalWidth.toDouble(), "height" to display.mode.physicalHeight.toDouble())
            } else {
              resolution = mapOf("width" to display.width.toDouble(), "height" to display.height.toDouble())
            }

            val receiveParameters = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "receiveParametersListener")
            receiveParameters.setStreamHandler(ExternalViewHandler(this))
            val sendParameters = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sendParameters")
            sendParameters.setMethodCallHandler(ExternalViewHandler(this))

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

            result.success(resolution)
            return
          }
          result.success(false)
        }
      }

      // 等候外部顯示器可以接收參數
      "waitingTransferParametersReady" -> {
        val handler = Handler(Looper.getMainLooper())
        var sendFail = Runnable {
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

      // 發送參數到外部顯示頁面
      "sendParameters" -> {
        if (externalViewEvents != null) {
          externalViewEvents?.success(call.arguments)
          result.success(true)
        } else {
          result.success(false)
        }
      }

      else -> {
        result.notImplemented()
      }
    }
  }

  // 主頁面 Flutter 的開始監控 swift 傳回的資料
  override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink)
  {
    mainViewEvents = eventSink
    // 檢查是否已連接外部顯示器
    if (displayManager.displays.size > 1) {
      eventSink.success(true)
    }
    // 開始監控插入和拔出外部顯示器
    displayManager.registerDisplayListener(displayListener, Handler(Looper.getMainLooper()))
  }

  // 主頁面 Flutter 的停止監控 swift 傳回的資料
  override fun onCancel(arguments: Any?)
  {
    // 停止監控插入和拔出外部顯示器
    displayManager.unregisterDisplayListener(displayListener)
    // 取消 swift 傳回的資料功能
    mainViewEvents = null
  }

  // 從 FlutterEngine 移除時執行
  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    eventChannel.setStreamHandler(null)
    methodChannel.setMethodCallHandler(null)
  }
}

// 外部顯示頁面 Flutter 開始和停止對 swift 傳送資料的監控
class ExternalViewHandler constructor(plugin: ExternalDisplayPlugin) : MethodCallHandler, StreamHandler {
  val externalDisplayPlugin = plugin

  // 接收外部顯示頁面的命令和參數
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    externalDisplayPlugin.mainViewEvents?.success(call.arguments)
  }

  // 外部顯示頁面 Flutter 的停止監控 swift 傳回的資料
  override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink)
  {
    externalDisplayPlugin.externalViewEvents = eventSink
    externalDisplayPlugin.connectReturn?.invoke()
  }

  // 外部顯示頁面 Flutter 的停止監控 swift 傳回的資料
  override fun onCancel(arguments: Any?)
  {
    externalDisplayPlugin.externalViewEvents = null
  }
}
