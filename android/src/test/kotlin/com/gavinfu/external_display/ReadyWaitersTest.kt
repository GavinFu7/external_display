package com.gavinfu.external_display

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ReadyWaitersTest {
  @Test
  fun notifyReadyRunsEveryWaiterAndClears() {
    val waiters = ReadyWaiters()
    var first = 0
    var second = 0
    waiters.add { first++ }
    waiters.add { second++ }
    assertEquals(2, waiters.size)

    waiters.notifyReady()

    assertEquals(1, first)
    assertEquals(1, second)
    assertEquals(0, waiters.size)
  }

  @Test
  fun removeByTokenLeavesTheOtherWaiter() {
    val waiters = ReadyWaiters()
    var removed = 0
    var kept = 0
    val token = waiters.add { removed++ }
    waiters.add { kept++ }

    assertTrue(waiters.remove(token))
    assertFalse(waiters.remove(token))
    assertEquals(1, waiters.size)

    waiters.notifyReady()

    assertEquals(0, removed)
    assertEquals(1, kept)
  }

  @Test
  fun notifyReadyTwiceRunsEachWaiterOnce() {
    val waiters = ReadyWaiters()
    var first = 0
    var second = 0
    val token = waiters.add { first++ }
    waiters.add { second++ }

    waiters.notifyReady()
    waiters.notifyReady()

    assertEquals(1, first)
    assertEquals(1, second)
    assertFalse(waiters.remove(token))
  }
}
