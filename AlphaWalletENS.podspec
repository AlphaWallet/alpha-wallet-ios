#
#  Be sure to run `pod spec lint AlphaWalletENS.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|
  spec.name         = "AlphaWalletENS"
  spec.version      = "1.0.0"
  spec.summary      = "AlphaWallet ENS functionality"
  spec.description      = "ENS functionality"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Hwee-Boon Yar" => "hboon@motionobj.com" }
  spec.social_media_url   = "https://twitter.com/hboon"
  spec.homepage     = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletENS"
  spec.ios.deployment_target = '13.0'
  spec.swift_version    = '5.0'
  spec.platform         = :ios, "13.0"
  spec.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{spec.version}" }
  spec.source_files     = 'modules/AlphaWalletENS/AlphaWalletENS/**/*.{h,m,swift}'
  spec.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  spec.dependency 'AlphaWalletAddress'
  spec.dependency 'PromiseKit'
  spec.dependency 'AlphaWalletWeb3'
  spec.dependency 'AlphaWalletCore'
end
