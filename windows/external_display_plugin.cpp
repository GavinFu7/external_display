#include "external_display_plugin.h"

#include <windows.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <vector>
#include <thread>
#include <map>
#include <string>

namespace external_display {

// Static member initialization
HWND ExternalDisplayPlugin::external_window_ = nullptr;
void* ExternalDisplayPlugin::receive_parameters_ = nullptr;
void* ExternalDisplayPlugin::send_parameters_ = nullptr;
void* ExternalDisplayPlugin::main_view_events_ = nullptr;
void* ExternalDisplayPlugin::external_view_events_ = nullptr;

// Window proc for external window
LRESULT CALLBACK ExternalWindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  if (msg == WM_DESTROY || msg == WM_CLOSE) {
    if (ExternalDisplayPlugin::main_view_events_ != nullptr) {
      static_cast<flutter::EventSink<flutter::EncodableValue>*>(ExternalDisplayPlugin::main_view_events_)
          ->Success(flutter::EncodableValue(false));
    }
    PostQuitMessage(0);
  }
  return DefWindowProcW(hwnd, msg, wparam, lparam);
}

// Get display information
struct DisplayInfo {
  std::string name;
  int width;
  int height;
  HMONITOR monitor;
};

BOOL CALLBACK MonitorEnumProc(HMONITOR monitor, HDC hdc, LPRECT lprc, LPARAM data) {
  auto* displays = reinterpret_cast<std::vector<DisplayInfo>*>(data);
  
  MONITORINFOEX mi;
  mi.cbSize = sizeof(mi);
  GetMonitorInfoW(monitor, &mi);
  
  DisplayInfo info;
  info.monitor = monitor;
  info.width = mi.rcMonitor.right - mi.rcMonitor.left;
  info.height = mi.rcMonitor.bottom - mi.rcMonitor.top;
  
  // Convert wide char to UTF-8
  char device_name[128] = {};
  WideCharToMultiByte(CP_UTF8, 0, mi.szDevice, -1, device_name, sizeof(device_name), nullptr, nullptr);
  info.name = device_name;
  
  displays->push_back(info);
  return TRUE;
}

std::vector<DisplayInfo> GetDisplays() {
  std::vector<DisplayInfo> displays;
  EnumDisplayMonitors(nullptr, nullptr, MonitorEnumProc, reinterpret_cast<LPARAM>(&displays));
  return displays;
}

// static
void ExternalDisplayPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  // Create and set up the method channel for displayController
  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "displayController",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ExternalDisplayPlugin>();

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

ExternalDisplayPlugin::ExternalDisplayPlugin() {}

ExternalDisplayPlugin::~ExternalDisplayPlugin() {}

void ExternalDisplayPlugin::GetScreen(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto displays = GetDisplays();
  flutter::EncodableList screen_list;
  
  for (size_t i = 0; i < displays.size(); ++i) {
    const auto& display = displays[i];
    std::ostringstream oss;
    oss << i << ". [" << display.width << "x" << display.height << "]";
    screen_list.push_back(flutter::EncodableValue(oss.str()));
  }
  
  result->Success(flutter::EncodableValue(screen_list));
}

void ExternalDisplayPlugin::CreateExternalWindow(
    const flutter::EncodableValue& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  // Get parameters
  std::string title = "External View";
  bool fullscreen = false;
  int width = 1920;
  int height = 1080;
  int target_screen = -1;

  flutter::EncodableMap arg_map;
  if (std::holds_alternative<flutter::EncodableMap>(args)) {
    arg_map = std::get<flutter::EncodableMap>(args);
  }

  auto get_value = [&](const std::string& key) -> const flutter::EncodableValue* {
    auto it = arg_map.find(flutter::EncodableValue(key));
    return it != arg_map.end() ? &it->second : nullptr;
  };

  if (auto value = get_value("title")) {
    if (std::holds_alternative<std::string>(*value)) {
      title = std::get<std::string>(*value);
    }
  }
  if (auto value = get_value("fullscreen")) {
    if (std::holds_alternative<bool>(*value)) {
      fullscreen = std::get<bool>(*value);
    }
  }
  if (auto value = get_value("width")) {
    if (std::holds_alternative<int32_t>(*value)) {
      width = std::get<int32_t>(*value);
    }
  }
  if (auto value = get_value("height")) {
    if (std::holds_alternative<int32_t>(*value)) {
      height = std::get<int32_t>(*value);
    }
  }
  if (auto value = get_value("targetScreen")) {
    if (std::holds_alternative<int32_t>(*value)) {
      target_screen = std::get<int32_t>(*value);
    }
  }

  auto displays = GetDisplays();
  
  RECT rect = {0, 0, width, height};
  
  if (target_screen >= 0 && target_screen < static_cast<int>(displays.size())) {
    auto& display = displays[target_screen];
    rect.left = display.width / 2 - width / 2;
    rect.top = display.height / 2 - height / 2;
    rect.right = rect.left + width;
    rect.bottom = rect.top + height;
  }

  // Register window class
  WNDCLASSW wc = {};
  wc.lpfnWndProc = ExternalWindowProc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = L"ExternalDisplayWindow";
  RegisterClassW(&wc);

  // Create external window
  HWND hwnd = CreateWindowExW(
      0,
      L"ExternalDisplayWindow",
      std::wstring(title.begin(), title.end()).c_str(),
      WS_OVERLAPPEDWINDOW,
      rect.left, rect.top, width, height,
      nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);

  if (hwnd) {
    external_window_ = hwnd;
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    
    if (main_view_events_ != nullptr) {
      static_cast<flutter::EventSink<flutter::EncodableValue>*>(main_view_events_)
          ->Success(flutter::EncodableValue(true));
    }
    
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Success(flutter::EncodableValue(false));
  }
}

void ExternalDisplayPlugin::DestroyExternalWindow(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (external_window_ != nullptr) {
    PostMessageW(external_window_, WM_DESTROY, 0, 0);
    external_window_ = nullptr;
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Success(flutter::EncodableValue(false));
  }
}

void ExternalDisplayPlugin::Connect(
    const flutter::EncodableValue& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (external_window_ == nullptr) {
    result->Success(flutter::EncodableValue(false));
    return;
  }

  RECT rect;
  if (GetClientRect(external_window_, &rect)) {
    int width = rect.right - rect.left;
    int height = rect.bottom - rect.top;
    
    flutter::EncodableMap size_map;
    size_map[flutter::EncodableValue("width")] = flutter::EncodableValue(width);
    size_map[flutter::EncodableValue("height")] = flutter::EncodableValue(height);
    
    result->Success(flutter::EncodableValue(size_map));
  } else {
    result->Success(flutter::EncodableValue(false));
  }
}

void ExternalDisplayPlugin::Disconnect(
    const flutter::EncodableValue& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(true));
}

void ExternalDisplayPlugin::WaitingTransferParametersReady(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool ready = external_view_events_ != nullptr;
  result->Success(flutter::EncodableValue(ready));
}

void ExternalDisplayPlugin::SendParameters(
    const flutter::EncodableValue& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (external_view_events_ != nullptr) {
    static_cast<flutter::EventSink<flutter::EncodableValue>*>(external_view_events_)
        ->Success(flutter::EncodableValue(args));
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Success(flutter::EncodableValue(false));
  }
}

void ExternalDisplayPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method_name = method_call.method_name();
  const auto* arguments = method_call.arguments();

  if (method_name == "getScreen") {
    GetScreen(std::move(result));
  } else if (method_name == "createWindow") {
    if (arguments && std::holds_alternative<flutter::EncodableMap>(*arguments)) {
      CreateExternalWindow(*arguments, std::move(result));
    } else {
      CreateExternalWindow(flutter::EncodableValue(), std::move(result));
    }
  } else if (method_name == "destroyWindow") {
    DestroyExternalWindow(std::move(result));
  } else if (method_name == "connect") {
    if (arguments && std::holds_alternative<flutter::EncodableMap>(*arguments)) {
      Connect(*arguments, std::move(result));
    } else {
      Connect(flutter::EncodableValue(), std::move(result));
    }
  } else if (method_name == "disconnect") {
    if (arguments && std::holds_alternative<flutter::EncodableMap>(*arguments)) {
      Disconnect(*arguments, std::move(result));
    } else {
      Disconnect(flutter::EncodableValue(), std::move(result));
    }
  } else if (method_name == "waitingTransferParametersReady") {
    WaitingTransferParametersReady(std::move(result));
  } else if (method_name == "sendParameters") {
    if (arguments && std::holds_alternative<flutter::EncodableMap>(*arguments)) {
      SendParameters(*arguments, std::move(result));
    } else {
      SendParameters(flutter::EncodableValue(), std::move(result));
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace external_display
