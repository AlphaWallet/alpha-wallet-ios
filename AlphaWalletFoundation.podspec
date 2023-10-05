#
#  Be sure to run `pod spec lint AlphaWalletFoundation.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|
  spec.name         = "AlphaWalletFoundation"
  spec.version      = "1.0.0"
  spec.summary      = "AlphaWallet functionality"
  spec.description      = "Core wallet functionality"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Vladyslav Shepitko" => "vladyslav.shepitko@gmail.com" }
  spec.homepage     = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletFoundation"
  spec.ios.deployment_target = '13.0'
  spec.swift_version    = '5.0'
  spec.platform         = :ios, "13.0"
  spec.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{spec.version}" }
  spec.source_files     = 'modules/AlphaWalletFoundation/AlphaWalletFoundation/**/*.{h,m,swift}'
  spec.resource_bundles = {'AlphaWalletFoundation' => ['modules/AlphaWalletFoundation/AlphaWalletFoundation/**/*.{graphql,json}'] }
  spec.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  #Other pods should almost never include AlphaWalletFoundation as a dependency in any other pod

  spec.dependency 'AlphaWalletWeb3'
  spec.dependency 'AlphaWalletWeb3Provider'
  spec.dependency 'AlphaWalletLogger'
  spec.dependency 'AlphaWalletABI'
  spec.dependency 'AlphaWalletAddress'
  spec.dependency 'AlphaWalletBrowser'
  spec.dependency 'AlphaWalletCore'
  spec.dependency 'AlphaWalletGoBack'
  spec.dependency 'AlphaWalletENS'
  spec.dependency 'AlphaWalletHardwareWallet'
  spec.dependency 'AlphaWalletOpenSea'
  spec.dependency 'AlphaWalletShareExtensionCore'
  spec.dependency 'AlphaWalletTokenScript'
  spec.dependency 'AlphaWalletTrustWalletCoreExtensions'
  spec.dependency 'BigInt', '~> 3.1'
  spec.dependency 'JSONRPCKit', '~> 2.0.0'
  spec.dependency 'APIKit', '5.1.0'
  spec.dependency 'RealmSwift', '10.36.0'
  spec.dependency 'CryptoSwift', '~> 1.4'
  spec.dependency 'TrezorCrypto'
  spec.dependency 'TrustKeystore'
  spec.dependency 'SwiftyJSON', '5.0.0'
  spec.dependency 'PromiseKit/CorePromise'
  spec.dependency 'Kanna'
  spec.dependency 'BlockiesSwift'
  spec.dependency 'PaperTrailLumberjack/Swift'
  spec.dependency 'Apollo', '0.53.0'
  spec.dependency 'CombineExt', '1.8.0'
  spec.dependency 'SwiftProtobuf', '~> 1.18.0'

end
