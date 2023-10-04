#
# Be sure to run `pod lib lint AlphaWalletABI.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletABI'
  s.version          = '1.0.0'
  s.summary          = 'AlphaWallet ABI library'
  s.description      = <<-DESC
  Lightweight library representing the AlphaWallet ABI functionality
                       DESC
  s.homepage         = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletABI"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author             = { "Hwee-Boon Yar" => "hboon@motionobj.com" }
  s.social_media_url   = "https://twitter.com/hboon"
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'
  s.platform         = :ios, "13.0"
  s.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{s.version}" }
  s.source_files     = 'modules/AlphaWalletABI/AlphaWalletABI/**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks       = 'Foundation'

  s.dependency 'AlphaWalletAddress'
  s.dependency 'AlphaWalletCore'
  s.dependency 'EthereumABI'
  s.dependency 'TrustKeystore'
end

