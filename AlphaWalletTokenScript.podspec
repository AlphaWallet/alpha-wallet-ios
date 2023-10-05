#
# Be sure to run `pod lib lint AlphaWalletTokenScript.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletTokenScript'
  s.version          = '1.0.0'
  s.summary          = 'AlphaWallet TokenScript library'
  s.description      = <<-DESC
  Lightweight library representing the AlphaWallet TokenScript functionality
                       DESC
  s.homepage         = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletTokenScript"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author             = { "Hwee-Boon Yar" => "hboon@motionobj.com" }
  s.social_media_url   = "https://twitter.com/hboon"
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'
  s.platform         = :ios, "13.0"
  s.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{s.version}" }
  s.source_files     = 'modules/AlphaWalletTokenScript/AlphaWalletTokenScript/**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks       = 'Foundation'

  s.dependency 'APIKit'
  s.dependency 'BigInt'
  s.dependency 'Kanna'
  s.dependency 'PromiseKit/CorePromise'
  s.dependency 'AlphaWalletAddress'
  s.dependency 'AlphaWalletABI'
  s.dependency 'AlphaWalletAttestation'
  s.dependency 'AlphaWalletBrowser'
  s.dependency 'AlphaWalletCore'
  s.dependency 'AlphaWalletLogger'
  s.dependency 'AlphaWalletOpenSea'
  s.dependency 'AlphaWalletWeb3'
  s.dependency 'CryptoSwift'
end
