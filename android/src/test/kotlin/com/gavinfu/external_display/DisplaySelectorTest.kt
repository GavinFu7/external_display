package com.gavinfu.external_display

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DisplaySelectorTest {
  @Test
  fun chooseTargetInAllIdsWinsEvenIfNotPresentationDisplay() {
    assertEquals(3, DisplaySelector.choose(3, listOf(2), listOf(0, 2, 3)))
  }

  @Test
  fun chooseWithoutTargetPicksFirstPresentationDisplay() {
    assertEquals(2, DisplaySelector.choose(-1, listOf(2, 4), listOf(0, 2, 4)))
  }

  @Test
  fun chooseWithoutPresentationDisplaysPicksLastNonDefault() {
    assertEquals(7, DisplaySelector.choose(-1, emptyList(), listOf(0, 5, 7)))
    assertEquals(5, DisplaySelector.choose(-1, emptyList(), listOf(5, 0)))
  }

  @Test
  fun chooseWithOnlyDefaultDisplayIsNull() {
    assertNull(DisplaySelector.choose(-1, emptyList(), listOf(0)))
  }

  @Test
  fun chooseTargetNotInAllIdsFallsThrough() {
    assertEquals(2, DisplaySelector.choose(9, listOf(2), listOf(0, 2)))
    assertEquals(5, DisplaySelector.choose(9, emptyList(), listOf(0, 5)))
    assertNull(DisplaySelector.choose(9, emptyList(), listOf(0)))
  }

  @Test
  fun chooseIgnoresNonPositiveTarget() {
    assertEquals(2, DisplaySelector.choose(0, listOf(2), listOf(0, 2)))
  }

  @Test
  fun isPluggedOnlyDefaultDisplay() {
    assertFalse(DisplaySelector.isPlugged(emptyList(), listOf(0)))
  }

  @Test
  fun isPluggedNonDefaultDisplayWithoutPresentationFlag() {
    assertTrue(DisplaySelector.isPlugged(emptyList(), listOf(0, 5)))
  }

  @Test
  fun isPluggedPresentationDisplay() {
    assertTrue(DisplaySelector.isPlugged(listOf(2), listOf(0, 2)))
  }
}
