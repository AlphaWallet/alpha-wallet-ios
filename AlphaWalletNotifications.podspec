#
# Be sure to run `pod lib lint AlphaWalletNotifications.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletNotifications'
  s.version          = '1.0.1'
  s.summary          = 'AlphaWallet Notifications library'
  s.description      = <<-DESC
  Lightweight library representing the AlphaWallet Notifications functionality
                       DESC
  s.homepage         = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletNotifications"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Vladyslav Shepitko' => 'vladyslav.shepitko@gmail.com' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '4.2'
  s.platform         = :ios, "13.0"
  s.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{s.version}" }
  s.source_files     = 'modules/AlphaWalletNotifications/AlphaWalletNotifications/**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks       = 'Foundation'

  s.dependency 'AlphaWalletCore'
  s.dependency 'AlphaWalletFoundation'
  s.dependency 'FirebaseCrashlytics'
  s.dependency 'Firebase/Messaging'
  s.dependency 'SwiftyJSON'
  
end
