#include "external_display_plugin.h"

#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <vector>
#include <thread>
#include <map>

namespace external_display {

// Static member initialization
HWND ExternalDisplayPlugin::external_window_ = nullptr;
std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> ExternalDisplayPlugin::monitor_state_listener_;
std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> ExternalDisplayPlugin::receive_parameters_;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> ExternalDisplayPlugin::send_parameters_;
flutter::EventSink<flutter::EncodableValue>* ExternalDisplayPlugin::main_view_events_ = nullptr;
flutter::EventSink<flutter::EncodableValue>* ExternalDisplayPlugin::external_view_events_ = nullptr;
std::function<void()> ExternalDisplayPlugin::connect_return_;

// Window proc for external window
LRESULT CALLBACK ExternalWindowProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  if (msg == WM_DESTROY || msg == WM_CLOSE) {
    if (ExternalDisplayPlugin::main_view_events_ != nullptr) {
      ExternalDisplayPlugin::main_view_events_->Success(flutter::EncodableValue(false));
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
  WideCharToMultiByte(CP_UTF8, 0, mi.szDevice, -1, 
                      reinterpret_cast<char*>(&info.name), 32, nullptr, nullptr);
  
  displays->push_back(info);
  return TRUE;
}

std::vector<DisplayInfo> GetDisplays() {
  std::vector<DisplayInfo> displays;
  EnumDisplayMonitors(nullptr, nullptr, MonitorEnumProc, reinterpret_cast<LPARAM>(&displays));
  return displays;
}

class FakeStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListen(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events) override {
    return nullptr;
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancel(
      const flutter::EncodableValue* arguments) override {
    return nullptr;
  }
};

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

  // Create the event channel for monitor state listener
  monitor_state_listener_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "monitorStateListener",
          &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<FakeStreamHandler>();
  monitor_state_listener_->SetStreamHandler(std::move(handler));

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

void ExternalDisplayPlugin::CreateWindow(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  // Get parameters
  std::string title = "External View";
  bool fullscreen = false;
  int width = 1920;
  int height = 1080;
  int target_screen = -1;

  if (args.find(flutter::EncodableValue("title")) != args.end()) {
    if (std::holds_alternative<std::string>(args.at(flutter::EncodableValue("title")))) {
      title = std::get<std::string>(args.at(flutter::EncodableValue("title")));
    }
  }
  if (args.find(flutter::EncodableValue("fullscreen")) != args.end()) {
    if (std::holds_alternative<bool>(args.at(flutter::EncodableValue("fullscreen")))) {
      fullscreen = std::get<bool>(args.at(flutter::EncodableValue("fullscreen")));
    }
  }
  if (args.find(flutter::EncodableValue("width")) != args.end()) {
    if (std::holds_alternative<int32_t>(args.at(flutter::EncodableValue("width")))) {
      width = std::get<int32_t>(args.at(flutter::EncodableValue("width")));
    }
  }
  if (args.find(flutter::EncodableValue("height")) != args.end()) {
    if (std::holds_alternative<int32_t>(args.at(flutter::EncodableValue("height")))) {
      height = std::get<int32_t>(args.at(flutter::EncodableValue("height")));
    }
  }
  if (args.find(flutter::EncodableValue("targetScreen")) != args.end()) {
    if (std::holds_alternative<int32_t>(args.at(flutter::EncodableValue("targetScreen")))) {
      target_screen = std::get<int32_t>(args.at(flutter::EncodableValue("targetScreen")));
    }
  }

  std::thread([title, fullscreen, width, height, target_screen, 
               result = std::move(result)]() mutable {
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
        main_view_events_->Success(flutter::EncodableValue(true));
      }
      
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Success(flutter::EncodableValue(false));
    }
  }).detach();
}

void ExternalDisplayPlugin::DestroyWindow(
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
    const flutter::EncodableMap& args,
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
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(true));
}

void ExternalDisplayPlugin::WaitingTransferParametersReady(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  // Simple timeout mechanism
  std::thread([result = std::move(result)]() mutable {
    for (int i = 0; i < 100; ++i) {
      if (external_view_events_ != nullptr) {
        result->Success(flutter::EncodableValue(true));
        return;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    result->Success(flutter::EncodableValue(false));
  }).detach();
}

void ExternalDisplayPlugin::SendParameters(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (external_view_events_ != nullptr) {
    external_view_events_->Success(flutter::EncodableValue(args));
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
      CreateWindow(std::get<flutter::EncodableMap>(*arguments), std::move(result));
    } else {
      CreateWindow(flutter::EncodableMap(), std::move(result));
    }
  } else if (method_name == "destroyWindow") {
    DestroyWindow(std::move(result));
  } else if (method_name == "connect") {
    if (arguments && std::holds_alternative<flutter::EncodableMap>(*arguments)) {
      Connect(std::get<flutter::EncodableMap>(*arguments), std::move(result));
    } else {
      Connect(flutter::EncodableMap(), std::move(result));
    }
  } else if (method_name == "disconnect") {
    if (arguments && std::holds_alternative<flutter::EncodableMap>(*arguments)) {
      Disconnect(std::get<flutter::EncodableMap>(*arguments), std::move(result));
    } else {
      Disconnect(flutter::EncodableMap(), std::move(result));
    }
  } else if (method_name == "waitingTransferParametersReady") {
    WaitingTransferParametersReady(std::move(result));
  } else if (method_name == "sendParameters") {
    if (arguments && std::holds_alternative<flutter::EncodableMap>(*arguments)) {
      SendParameters(std::get<flutter::EncodableMap>(*arguments), std::move(result));
    } else {
      SendParameters(flutter::EncodableMap(), std::move(result));
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace external_display
