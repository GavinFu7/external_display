package com.gavinfu.external_display

import kotlin.test.Test
import kotlin.test.assertEquals

class MethodCallArgsTest {
  @Test
  fun routeNameUsesProvidedValue() {
    assertEquals(
      "secondary",
      MethodCallArgs.routeName(mapOf("routeName" to "secondary", "targetScreen" to 2)),
    )
  }

  @Test
  fun routeNameFallsBackToDefault() {
    assertEquals("externalView", MethodCallArgs.routeName(null))
    assertEquals("externalView", MethodCallArgs.routeName(emptyMap<String, Any?>()))
    assertEquals("externalView", MethodCallArgs.routeName(mapOf("routeName" to null)))
  }

  @Test
  fun targetScreenUsesProvidedValue() {
    assertEquals(3, MethodCallArgs.targetScreen(mapOf("targetScreen" to 3)))
    assertEquals(3, MethodCallArgs.targetScreen(mapOf("targetScreen" to 3L)))
  }

  @Test
  fun targetScreenFallsBackToDefault() {
    assertEquals(-1, MethodCallArgs.targetScreen(null))
    assertEquals(-1, MethodCallArgs.targetScreen(emptyMap<String, Any?>()))
    assertEquals(-1, MethodCallArgs.targetScreen(mapOf("targetScreen" to null)))
  }
}
