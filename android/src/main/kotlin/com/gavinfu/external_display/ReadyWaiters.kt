package com.gavinfu.external_display

/** Callbacks waiting for an external view to subscribe; each one runs at most once. */
internal class ReadyWaiters {
  private class Waiter(val onReady: () -> Unit, val onCancel: () -> Unit)

  private val waiters = LinkedHashMap<Any, Waiter>()

  val size: Int
    get() = waiters.size

  /** Registers [onReady] and returns the token that [remove] takes. */
  fun add(onReady: () -> Unit): Any {
    return add(onReady) {}
  }

  /** Registers [onReady], with [onCancel] run instead by [cancelAll]; returns the token. */
  fun add(onReady: () -> Unit, onCancel: () -> Unit): Any {
    val token = Any()
    waiters[token] = Waiter(onReady, onCancel)
    return token
  }

  /** Unregisters the waiter of [token]; false when it already ran or was removed. */
  fun remove(token: Any): Boolean {
    return waiters.remove(token) != null
  }

  /** Runs every registered waiter and clears the registry. */
  fun notifyReady() {
    val ready = waiters.values.toList()
    waiters.clear()
    ready.forEach { it.onReady() }
  }

  /** Runs every registered waiter's cancel callback instead and clears the registry. */
  fun cancelAll() {
    val cancelled = waiters.values.toList()
    waiters.clear()
    cancelled.forEach { it.onCancel() }
  }
}
