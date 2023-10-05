#
# Be sure to run `pod lib lint AlphaWalletAttestation.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
s.name             = "AlphaWalletAttestation"
s.version          = "0.0.1"
s.summary          = "Attestation functionality"
s.description      = "Attestation functionality"
s.homepage     = "https://github.com/AlphaWallet/alpha-wallet-ios/tree/master/modules/AlphaWalletAttestation"
s.license      = { :type => "MIT", :file => "LICENSE" }
s.author             = { "Hwee-Boon Yar" => "hboon@motionobj.com" }
s.social_media_url   = "https://twitter.com/hboon"
s.source       = { :git => 'git@github.com:AlphaWallet/alpha-wallet-ios.git', :tag => "#{s.version}" }

s.swift_version = '5.0'
s.module_name = 'AlphaWalletAttestation'
s.ios.deployment_target = "10.0"
s.osx.deployment_target = "10.11"
s.source_files     = 'modules/AlphaWalletAttestation/AlphaWalletAttestation/**/*.{h,m,swift}'
s.public_header_files = "AlphaWalletAttestation/**/*.{h}"
s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

s.dependency 'AlphaWalletABI'
s.dependency 'AlphaWalletAddress'
s.dependency 'AlphaWalletCore'
s.dependency 'AlphaWalletWeb3'
s.dependency 'BigInt'
s.dependency 'GzipSwift'

end
