package com.gavinfu.external_display

/** Callbacks waiting for an external view to subscribe; each one runs at most once. */
internal class ReadyWaiters {
  private val waiters = LinkedHashMap<Any, () -> Unit>()

  val size: Int
    get() = waiters.size

  /** Registers [onReady] and returns the token that [remove] takes. */
  fun add(onReady: () -> Unit): Any {
    val token = Any()
    waiters[token] = onReady
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
    ready.forEach { it() }
  }
}
