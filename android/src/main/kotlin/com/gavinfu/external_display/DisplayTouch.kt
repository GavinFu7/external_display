package com.gavinfu.external_display

import android.content.res.Configuration

/** Maps Android's `Configuration.touchscreen` to the three-state `hasTouch` value. */
internal object DisplayTouch {
  /**
   * Returns `true` for a finger or stylus touchscreen, `false` for no touchscreen, and `null`
   * for an undefined or unknown value.
   */
  // TOUCHSCREEN_STYLUS is deprecated, but a system that reports it still has a touchscreen.
  @Suppress("DEPRECATION")
  fun fromConfiguration(touchscreen: Int): Boolean? {
    return when (touchscreen) {
      Configuration.TOUCHSCREEN_FINGER, Configuration.TOUCHSCREEN_STYLUS -> true
      Configuration.TOUCHSCREEN_NOTOUCH -> false
      else -> null
    }
  }
}
