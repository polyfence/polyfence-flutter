Pod::Spec.new do |s|
  s.name             = 'polyfence'
  s.version          = '0.12.0'
  s.summary          = 'Privacy-first polygon and circle geofencing for Flutter'
  s.description      = <<-DESC
Privacy-first polygon and circle geofencing for Flutter. True background tracking without external dependencies.
                       DESC
  s.homepage         = 'https://github.com/blackabass/polyfence'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Polyfence' => 'hello@polyfence.io' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.swift_version = '5.0'
  
  # Add required system frameworks
  s.frameworks = 'CoreLocation', 'CoreMotion', 'UserNotifications'
  
  # Add background modes capability
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
