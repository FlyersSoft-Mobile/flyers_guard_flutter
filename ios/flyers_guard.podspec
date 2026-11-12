Pod::Spec.new do |s|
  s.name             = 'flyers_guard'
  s.version          = '1.0.0'
  s.summary          = 'Flutter bridge over the prebuilt FlyersGuard iOS SDK (jailbreak detection).'
  s.description      = <<-DESC
A thin Flutter method-channel bridge over the prebuilt FlyersGuard.xcframework.
The jailbreak-detection logic ships as a compiled binary framework; no native
detection source is distributed in this package.
                       DESC
  s.homepage         = 'https://github.com/FlyersSoft-Mobile/flyers_guard_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'FlyersSoft' => 'mobile@flyerssoft.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Prebuilt detection SDK, vendored as a binary XCFramework.
  s.vendored_frameworks = 'Frameworks/FlyersGuard.xcframework'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
