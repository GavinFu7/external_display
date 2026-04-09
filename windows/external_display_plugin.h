#ifndef FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_
#define FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#undef CreateWindow
#undef DestroyWindow

#include <memory>
#include <functional>
#include <string>

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
  static void* receive_parameters_;
  static void* send_parameters_;
  static void* main_view_events_;
  static void* external_view_events_;

  // Method handlers
  void GetScreen(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void CreateExternalWindow(
      const flutter::EncodableValue& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DestroyExternalWindow(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Connect(
      const flutter::EncodableValue& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Disconnect(
      const flutter::EncodableValue& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void WaitingTransferParametersReady(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SendParameters(
      const flutter::EncodableValue& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  friend LRESULT CALLBACK ExternalWindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
};

}  // namespace external_display

#endif  // FLUTTER_PLUGIN_EXTERNAL_DISPLAY_PLUGIN_H_
