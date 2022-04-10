platform :ios, '13.0'
inhibit_all_warnings!
source 'https://cdn.cocoapods.org/'

target 'AlphaWallet' do
  use_frameworks!
  pod 'BigInt', '~> 3.1'
  pod 'R.swift'
  pod 'JSONRPCKit', '~> 2.0.0'
  pod 'APIKit', '5.1.0'
  pod 'MBProgressHUD'
  pod 'StatefulViewController'
  pod 'QRCodeReaderViewController', :git=>'https://github.com/AlphaWallet/QRCodeReaderViewController.git', :commit=>'30d1a2a7d167d0d207ae0ae3a4d81bcf473d7a65'
  pod 'KeychainSwift', :git=>'https://github.com/AlphaWallet/keychain-swift.git', :commit=> 'b797d40a9d08ec509db4335140cf2259b226e6a2'
  pod 'SwiftLint', '0.40.3'
  pod 'RealmSwift', '5.5.1'
  pod 'Moya', '~> 10.0.1'
  pod 'CryptoSwift', '~> 1.4'
  pod 'Kingfisher', '5.15.7'
  pod 'AlphaWalletWeb3Provider', :git=>'https://github.com/AlphaWallet/AlphaWallet-web3-provider', :commit => '9a4496d02b7ddb2f6307fd0510d8d7c9fcef9870'
  pod 'TrezorCrypto', :git=>'https://github.com/AlphaWallet/trezor-crypto-ios.git', :commit => '50c16ba5527e269bbc838e80aee5bac0fe304cc7'
  pod 'TrustKeystore', :git => 'https://github.com/AlphaWallet/latest-keystore-snapshot', :commit => 'c0bdc4f6ffc117b103e19d17b83109d4f5a0e764'
  pod 'SwiftyJSON', '5.0.0'
  pod 'web3swift', :git => 'https://github.com/AlphaWallet/web3swift.git', :commit=> '0b4cca278f9b7d29be1e880e75d7a8e6a8812d1c'
  pod 'SAMKeychain'
  pod 'PromiseKit/CorePromise'
  pod 'PromiseKit/Alamofire'
  pod "Kanna", :git => 'https://github.com/tid-kijyun/Kanna.git', :commit => '06a04bc28783ccbb40efba355dee845a024033e8'
  pod 'TrustWalletCore', '2.6.34'
  pod 'AWSSNS', '2.18.0'
  pod 'Mixpanel-swift', '2.8.0'
  pod 'EthereumABI', '1.3.0'
  pod 'BlockiesSwift'
  pod 'PaperTrailLumberjack/Swift'
  pod 'WalletConnectSwift', :git => 'https://github.com/WalletConnect/WalletConnectSwift.git'
  pod 'Charts'
  pod 'CocoaLumberjack', '3.7.0'
  pod 'AlphaWalletAddress', :path => 'modules/AlphaWalletAddress'
  pod 'AlphaWalletCore', :path => 'modules/AlphaWalletCore'
  pod 'AlphaWalletENS', :path => 'modules/AlphaWalletENS'
  pod 'Apollo' 
  pod 'MailchimpSDK'
  pod 'xcbeautify'
  pod 'FloatingPanel'

  target 'AlphaWalletTests' do
      inherit! :search_paths
      # Pods for testing
      pod 'iOSSnapshotTestCase', '6.2.0'
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      config.build_settings['ENABLE_BITCODE'] = 'YES'
    end
    
    if ['MailchimpSDK'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings["ARCHS[sdk=iphonesimulator*]"] = "x86_64"
      end
    end

    if ['TrustKeystore'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Owholemodule'
      end
    end
    if ['Result', 'SwiftyXMLParser', 'JSONRPCKit'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
      end
    end

    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0';
    end
  end
end
