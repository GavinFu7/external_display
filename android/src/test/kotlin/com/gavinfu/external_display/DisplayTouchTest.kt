package com.gavinfu.external_display

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class DisplayTouchTest {
  @Test
  fun fingerMeansTouch() {
    // Configuration.TOUCHSCREEN_FINGER
    assertEquals(true, DisplayTouch.fromConfiguration(3))
  }

  @Test
  fun stylusMeansTouch() {
    // Configuration.TOUCHSCREEN_STYLUS
    assertEquals(true, DisplayTouch.fromConfiguration(2))
  }

  @Test
  fun noTouchMeansNoTouch() {
    // Configuration.TOUCHSCREEN_NOTOUCH
    assertEquals(false, DisplayTouch.fromConfiguration(1))
  }

  @Test
  fun undefinedIsUnknown() {
    // Configuration.TOUCHSCREEN_UNDEFINED
    assertNull(DisplayTouch.fromConfiguration(0))
  }

  @Test
  fun unknownValueIsUnknown() {
    assertNull(DisplayTouch.fromConfiguration(4))
    assertNull(DisplayTouch.fromConfiguration(-1))
  }
}
