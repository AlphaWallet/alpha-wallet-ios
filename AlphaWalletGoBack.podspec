#
# Be sure to run `pod lib lint AlphaWalletGoBack.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletGoBack'
  s.version          = '1.0.0'
  s.summary          = 'Alpha Wallet GoBack library'
  s.description      = <<-DESC
  Lightweight library representing the AlphaWalletGoBack with its functionality
                       DESC
  s.homepage         = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletGoBack"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Hwee-Boon Yar" => "hboon@motionobj.com" }
  s.ios.deployment_target = '12.0'
  s.swift_version    = '5.0'
  s.platform         = :ios, "12.0"
  s.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{s.version}" }
  s.source_files     = 'modules/AlphaWalletGoBack/AlphaWalletGoBack/**/*.{h,m}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks       = 'UIKit'
  #Should not include any of our own pods as dependency unless that pod is never going to have a dependency on this pod
end
