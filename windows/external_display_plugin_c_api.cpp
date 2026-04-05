#include "include/external_display/external_display_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "external_display_plugin.h"

void ExternalDisplayPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  external_display::ExternalDisplayPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
