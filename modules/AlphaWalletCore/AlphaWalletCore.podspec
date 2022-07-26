#
# Be sure to run `pod lib lint AlphaWalletCore.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletCore'
  s.version          = '1.0.2'
  s.summary          = 'AlphaWallet core library'
  s.description      = <<-DESC
  Lightweight library representing the AlphaWallet core with its functionality
                       DESC
  s.homepage         = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletCore"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Krypto Pank' => 'krypto.pank@gmail.com' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '4.2'
  s.platform         = :ios, "13.0"
  s.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{s.version}" }
  s.source_files     = 'AlphaWalletCore/**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks       = 'Foundation'

  s.dependency 'PromiseKit'
end
