Pod::Spec.new do |s|
  s.name         = 'TSNetworkingSwift'
  s.version      = '0.0.1'
  s.summary      = 'An iOS8+ networking API based on NSURLSession, written in Swift'
  s.homepage     = 'https://github.com/timsawtell/TSNetworkingSwift'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = 'timsawtell'
  s.platform     = :ios, '8.0'
  s.ios.deployment_target = '8.0'
  s.source       = { :git => 'https://github.com/timsawtell/TSNetworkingSwift.git', :tag => '0.0.1' }
  s.source_files = 'TSNetworkingSwift/TSNetworking.swift'
  s.requires_arc = true
  s.dependencies = ['AFNetworking/Security', 'Reachability']
end
