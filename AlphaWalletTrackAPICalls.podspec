#
# Be sure to run `pod lib lint AlphaWalletTrackAPICalls.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletTrackAPICalls'
  s.version          = '1.0.0'
  s.summary          = 'Track API calls'
  s.description      = 'Track API calls'
  s.homepage         = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletTrackAPICalls"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author             = { "Hwee-Boon Yar" => "hboon@motionobj.com" }
  s.social_media_url   = "https://twitter.com/hboon"
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'
  s.platform         = :ios, "13.0"
  s.source           = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{s.version}" }
  s.source_files     = 'modules/AlphaWalletTrackAPICalls/AlphaWalletTrackAPICalls/**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks = 'Foundation'
  # Should not include any of our own pods as dependency unless that pod is never going to have a dependency on this pod
end
