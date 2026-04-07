#ifndef FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_
#define FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <memory>
#include <functional>

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

 private:
  // Static members for multi-window support
  static HWND external_window_;
  static std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> monitor_state_listener_;
  static std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> receive_parameters_;
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> send_parameters_;
  static flutter::EventSink<flutter::EncodableValue>* main_view_events_;
  static flutter::EventSink<flutter::EncodableValue>* external_view_events_;
  static std::function<void()> connect_return_;

  // Method handlers
  void GetScreen(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void CreateWindow(const flutter::EncodableMap& args,
                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DestroyWindow(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Connect(const flutter::EncodableMap& args,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Disconnect(const flutter::EncodableMap& args,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void WaitingTransferParametersReady(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SendParameters(const flutter::EncodableMap& args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace external_display

#endif  // FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_
