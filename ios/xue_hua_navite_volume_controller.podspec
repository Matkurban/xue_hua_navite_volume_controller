#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint xue_hua_navite_volume_controller.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'xue_hua_navite_volume_controller'
  s.version          = '1.0.0'
  s.summary          = 'Cross-platform system & application audio volume controller plugin for Flutter.'
  s.description      = <<-DESC
Cross-platform system and application audio volume controller for Flutter across Android, iOS, macOS, Windows, Linux, and Web.
                       DESC
  s.homepage         = 'https://github.com/Matkurban/xue_hua_navite_volume_controller'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Matkurban' => '3496354336@qq.com' }
  s.source           = { :path => '.' }
  s.source_files = 'xue_hua_navite_volume_controller/Sources/xue_hua_navite_volume_controller/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'AVFoundation', 'MediaPlayer', 'UIKit'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
