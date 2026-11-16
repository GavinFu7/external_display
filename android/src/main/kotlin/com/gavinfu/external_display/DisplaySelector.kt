package com.gavinfu.external_display

/** Chooses the display for a presentation from plain display ids. */
internal object DisplaySelector {
  /**
   * Returns [targetScreen] when it is a positive id in [allIds]; otherwise the first of
   * [presentationIds]; otherwise the last of [allIds] that is not [defaultId]; otherwise null.
   */
  fun choose(
    targetScreen: Int,
    presentationIds: List<Int>,
    allIds: List<Int>,
    defaultId: Int = 0,
  ): Int? {
    if (targetScreen > 0 && targetScreen in allIds) {
      return targetScreen
    }
    return presentationIds.firstOrNull() ?: allIds.lastOrNull { it != defaultId }
  }

  /**
   * True when a presentation display exists, or any display other than [defaultId] (some
   * second screens lack the presentation flag).
   */
  fun isPlugged(presentationIds: List<Int>, allIds: List<Int>, defaultId: Int = 0): Boolean {
    return presentationIds.isNotEmpty() || allIds.any { it != defaultId }
  }
}
