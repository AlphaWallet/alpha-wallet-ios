#
#  Be sure to run `pod spec lint AlphaWalletShareExtensionCore.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|
  spec.name         = "AlphaWalletShareExtensionCore"
  spec.version      = "1.0.0"
  spec.summary      = "Shared code extracted from share extension"
  spec.description      = "This is code used in both share extension and main app that is extension safe, avoids compilation warning: ld: linking against a dylib which is not safe for use in application extensions"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Vladyslav Shepitko" => "vladyslav.shepitko@gmail.com" }
  spec.homepage     = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletShareExtensionCore"
  spec.ios.deployment_target = '13.0'
  spec.swift_version    = '5.0'
  spec.platform         = :ios, "13.0"
  spec.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{spec.version}" }
  spec.source_files     = 'modules/AlphaWalletShareExtensionCore/AlphaWalletShareExtensionCore/**/*.{h,m,swift}'
  spec.resource_bundles = {'AlphaWalletShareExtensionCore' => ['modules/AlphaWalletShareExtensionCore/AlphaWalletShareExtensionCore/**/*.{graphql,json}'] }
  spec.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  #Should not include any of our own pods as dependency unless that pod is never going to have a dependency on this pod
end
