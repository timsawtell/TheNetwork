Pod::Spec.new do |s|
  s.name         = 'TheNetwork'
  s.version      = '0.0.2'
  s.summary      = 'An iOS8+ networking API based on NSURLSession, written in Swift'
  s.homepage     = 'https://github.com/timsawtell/TheNetwork'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = 'timsawtell'
  s.platform     = :ios, '8.0'
  s.ios.deployment_target = '8.0'
  s.source       = { :git => 'https://github.com/timsawtell/TheNetwork.git' }
  s.source_files = 'TheNetwork/src/**/*.{h,m,swift}'
  s.requires_arc = true
end
