#
# Be sure to run `pod lib lint AlphaWalletCore.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AlphaWalletCore'
  s.version          = '1.0.1'
  s.summary          = 'Alpha Wallet core library'
  s.description      = <<-DESC
  Lightweight library representing the Alpha Wallet core with its functionality
                       DESC
  s.homepage         = 'https://github.com/oa-s/AlphaWalletCore'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Krypto Pank' => 'krypto.pank@gmail.com' }
  s.ios.deployment_target = '12.0'
  s.swift_version    = '4.0'
  s.platform         = :ios, "12.0"
  s.source           = { :git => 'git@github.com:oa-s/AlphaWalletCore.git', :tag => s.version.to_s }
  s.source_files     = 'AlphaWalletCore/**/*.{h,m,swift}'
  s.pod_target_xcconfig = { 'SWIFT_OPTIMIZATION_LEVEL' => '-Owholemodule' }

  s.frameworks       = 'Foundation'

end
