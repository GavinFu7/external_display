#ifndef FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_
#define FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace external_display {

class ExternalDisplayPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ExternalDisplayPlugin();

  virtual ~ExternalDisplayPlugin();

  // Disallow copy and assign.
  ExternalDisplayPlugin(const ExternalDisplayPlugin&) = delete;
  ExternalDisplayPlugin& operator=(const ExternalDisplayPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace external_display

#endif  // FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_
