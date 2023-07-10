#
# Be sure to run `pod lib lint AlphaWalletHardwareWallet.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletHardwareWallet'
  s.version          = '1.0.0'
  s.summary          = 'AlphaWallet HardwareWallet library'
  s.description      = <<-DESC
  Lightweight library representing the AlphaWallet HardwareWallet functionality
                       DESC
  s.homepage         = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletHardwareWallet"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author             = { "Hwee-Boon Yar" => "hboon@motionobj.com" }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'
  s.platform         = :ios, "13.0"
  s.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{s.version}" }
  s.source_files     = 'modules/AlphaWalletHardwareWallet/AlphaWalletHardwareWallet/**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks       = 'Foundation'

  s.dependency 'AlphaWalletAddress'
  s.dependency 'AlphaWalletTrustWalletCoreExtensions'
  s.dependency 'AlphaWalletWeb3'
  s.dependency 'TrustKeystore'
end

