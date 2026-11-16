package com.gavinfu.external_display

import android.annotation.SuppressLint
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display
import android.view.WindowManager

/** Builds the answer to `getDisplays`: one map per display that [DisplayManager] lists. */
internal object DisplayInfo {
  // WindowManager.LayoutParams.TYPE_PRESENTATION (FIRST_SYSTEM_WINDOW + 37) is hidden from the
  // SDK; android.app.Presentation creates its window context with this type.
  private const val TYPE_PRESENTATION = 2037

  fun list(context: Context, displayManager: DisplayManager): List<Map<String, Any?>> {
    val appContext = context.applicationContext
    return displayManager.displays.map { display ->
      mapOf(
        "id" to display.displayId,
        "name" to (display.name ?: ""),
        "width" to display.mode.physicalWidth.toDouble(),
        "height" to display.mode.physicalHeight.toDouble(),
        "isPrimary" to (display.displayId == Display.DEFAULT_DISPLAY),
        "hasTouch" to hasTouch(appContext, displayManager, display),
      )
    }
  }

  /**
   * Reads the `Configuration.touchscreen` that Android computes for [display] from the input
   * devices that can send events to it, or returns `null` when that value cannot be read.
   * Below Android 12L the default display reports the app's own configuration instead.
   */
  private fun hasTouch(
    context: Context,
    displayManager: DisplayManager,
    display: Display,
  ): Boolean? {
    // A window context on a display carries that display's configuration. Android 12L is the
    // first release that applies it before createWindowContext returns; Android 12 applies it
    // later on a binder thread, so reading it here could give the app's own configuration.
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S_V2) {
      // Only the app's own configuration can be read here. It is the default display's while
      // the app's activity is on that display, so it is used for the default display only.
      return if (display.displayId == Display.DEFAULT_DISPLAY) {
        DisplayTouch.fromConfiguration(context.resources.configuration.touchscreen)
      } else {
        null
      }
    }
    return try {
      val type = if ((display.flags and Display.FLAG_PRIVATE) != 0) {
        WindowManager.LayoutParams.TYPE_PRIVATE_PRESENTATION
      } else {
        TYPE_PRESENTATION
      }
      // Not cached: the window context adds no window and is released by its finalizer.
      // The SDK's lint typedef omits the hidden TYPE_PRESENTATION that Presentation itself uses.
      @SuppressLint("WrongConstant")
      val windowContext = context.createDisplayContext(display).createWindowContext(type, null)
      val touchscreen = windowContext.resources.configuration.touchscreen
      // If the display was removed before the window context attached, Android only logs a
      // warning and the context keeps the app's own configuration.
      if (displayManager.getDisplay(display.displayId) == null) {
        null
      } else {
        DisplayTouch.fromConfiguration(touchscreen)
      }
    } catch (e: Exception) {
      null
    }
  }
}
