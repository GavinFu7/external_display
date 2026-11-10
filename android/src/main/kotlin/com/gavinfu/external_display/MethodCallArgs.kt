package com.gavinfu.external_display

/** Helpers for reading Flutter MethodChannel map arguments. */
internal object MethodCallArgs {
  @Suppress("UNCHECKED_CAST")
  fun asMap(arguments: Any?): Map<String, Any?> {
    return arguments as? Map<String, Any?> ?: emptyMap()
  }

  fun routeName(arguments: Any?, default: String = "externalView"): String {
    return asMap(arguments)["routeName"] as? String ?: default
  }

  fun targetScreen(arguments: Any?, default: Int = -1): Int {
    return (asMap(arguments)["targetScreen"] as? Number)?.toInt() ?: default
  }
}
