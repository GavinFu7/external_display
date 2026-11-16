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

  @Test
  fun waiterAddedDuringNotifyReadyWaitsForTheNextOne() {
    val waiters = ReadyWaiters()
    var late = 0
    waiters.add { waiters.add { late++ } }

    waiters.notifyReady()

    assertEquals(0, late)
    assertEquals(1, waiters.size)

    waiters.notifyReady()

    assertEquals(1, late)
    assertEquals(0, waiters.size)
  }

  @Test
  fun cancelAllRunsOnCancelInsteadOfOnReadyAndClears() {
    val waiters = ReadyWaiters()
    var ready = 0
    var cancelled = 0
    val token = waiters.add({ ready++ }, { cancelled++ })
    waiters.add { ready++ }

    waiters.cancelAll()

    assertEquals(0, ready)
    assertEquals(1, cancelled)
    assertEquals(0, waiters.size)
    assertFalse(waiters.remove(token))
    waiters.notifyReady()
    assertEquals(0, ready)
  }

  @Test
  fun notifyReadyAndRemoveNeverRunOnCancel() {
    val waiters = ReadyWaiters()
    var cancelled = 0
    val removed = waiters.add({}, { cancelled++ })
    waiters.add({}, { cancelled++ })

    waiters.remove(removed)
    waiters.notifyReady()
    waiters.cancelAll()

    assertEquals(0, cancelled)
  }
}
