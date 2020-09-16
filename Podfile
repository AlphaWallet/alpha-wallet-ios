platform :ios, '10.0'
inhibit_all_warnings!
source 'https://cdn.cocoapods.org/'

target 'AlphaWallet' do
  use_frameworks!
  pod 'BigInt', '~> 3.0'
  pod 'R.swift'
  pod 'JSONRPCKit', '~> 2.0.0'
  pod 'APIKit'
  pod 'Eureka', '~> 5.2.1'
  pod 'MBProgressHUD'
  pod 'StatefulViewController'

  pod 'QRCodeReaderViewController', :git=>'https://github.com/AlphaWallet/QRCodeReaderViewController.git', :commit=>'30d1a2a7d167d0d207ae0ae3a4d81bcf473d7a65'
  pod 'KeychainSwift', :git=>'https://github.com/AlphaWallet/keychain-swift.git', :branch=>'alphawallet'
  pod 'SwiftLint'
  pod 'SeedStackViewController'
  pod 'RealmSwift', '~> 4.3.2'
  pod 'Moya', '~> 10.0.1'
  pod 'JavaScriptKit'
  pod 'CryptoSwift'
  pod 'SwiftyXMLParser', :git => 'https://github.com/yahoojapan/SwiftyXMLParser.git'
  pod 'Kingfisher'
  pod 'AlphaWalletWeb3Provider', :git=>'https://github.com/AlphaWallet/AlphaWallet-web3-provider', :commit => '1c1aafb566361e7067e69f6e38b0fdc30b801429'
  pod 'TrezorCrypto', :git=>'https://github.com/AlphaWallet/trezor-crypto-ios.git', :commit => '50c16ba5527e269bbc838e80aee5bac0fe304cc7'
  pod 'TrustKeystore', :git => 'https://github.com/alpha-wallet/trust-keystore.git', :commit => '37f7eaf9531cb4e33d06129543b3a56972f59d2a'
  pod 'SwiftyJSON'
  #pod 'web3swift', :git => 'https://github.com/alpha-wallet/web3swift.git', :commit => 'ae74a86c09dbec703e2aaf27217d7fb0722948ed'
  pod 'web3swift', :git => 'https://github.com/alpha-wallet/web3swift.git', :commit => '7e2b99198acb2243b6a539cb32832a96f67c893d'
 
  pod 'SAMKeychain'
  pod 'PromiseKit/CorePromise'
  pod 'PromiseKit/Alamofire'
  #To force SWXMLHash which Macaw depends on to be Swift >= 4
  pod 'SWXMLHash', '~> 5.0.0'
  pod "Macaw", :git => 'https://github.com/alpha-wallet/Macaw.git', :commit => 'e1f4eb1d2b81676fb10e9835c5e2ce9e9f51faf9'
  pod "Kanna", :git => 'https://github.com/tid-kijyun/Kanna.git', :commit => '06a04bc28783ccbb40efba355dee845a024033e8'
  pod 'TrustWalletCore'
  pod 'AWSSNS'
  pod 'Mixpanel-swift'
  # pod 'AWSCognito'
  target 'AlphaWalletTests' do
      inherit! :search_paths
      # Pods for testing
      pod 'iOSSnapshotTestCase'
  end

  target 'AlphaWalletUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    if ['TrustKeystore'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Owholemodule'
      end
    end
    if [
        'Result',
        'SwiftyXMLParser',
        'JSONRPCKit',
		'SWXMLHash'
    ].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
      end
    end
  end
end
