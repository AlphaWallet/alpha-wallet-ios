#
# Be sure to run `pod lib lint AlphaWalletAddress.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletAddress'
  s.version          = '1.0.1'
  s.summary          = 'Alpha Wallet Address library'
  s.description      = <<-DESC
  Lightweight library representing the Alpha Wallet Address with its functionality
                       DESC
  s.homepage         = 'https://github.com/vladyslav-iosdev/AlphaWalletAddress'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Vladyslav Shepitko' => 'vladyslav.shepitko@gmail.com' }
  s.ios.deployment_target = '12.0'
  s.swift_version    = '4.0'
  s.platform         = :ios, "12.0"
  s.source           = { :git => 'https://github.com/vladyslav-iosdev/AlphaWalletAddress.git', :tag => s.version.to_s }
  s.source_files     = 'AlphaWalletAddress/**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks       = 'Foundation'

  s.dependency 'TrustKeystore'
  s.dependency 'TrustWalletCore'
  
end
