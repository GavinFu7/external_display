#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint external_display.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'external_display'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for wired or wireless external displays.'
  s.description      = <<-DESC
The Flutter plugin supports connecting to an external display via wired or wireless connections.
                       DESC
  s.homepage         = 'https://github.com/GavinFu7/external_display'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'GavinFu7' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'external_display/Sources/external_display/**/*.swift'
  s.resource_bundles = {'external_display_privacy' => ['external_display/Sources/external_display/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
