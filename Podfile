platform :ios, '12.0'
inhibit_all_warnings!
source 'https://cdn.cocoapods.org/'

target 'AlphaWallet' do
  use_frameworks!
  pod 'BigInt', '~> 3.1'
  pod 'R.swift'
  pod 'JSONRPCKit', '~> 2.0.0'
  pod 'APIKit', '5.1.0'
  pod 'Eureka', :git=> 'https://github.com/xmartlabs/Eureka.git', :commit => '5c54e2607632ce586010e50e91d9adcb6bb3909e'
  pod 'MBProgressHUD'
  pod 'StatefulViewController'

  pod 'QRCodeReaderViewController', :git=>'https://github.com/AlphaWallet/QRCodeReaderViewController.git', :commit=>'30d1a2a7d167d0d207ae0ae3a4d81bcf473d7a65'
  pod 'KeychainSwift', :git=>'https://github.com/AlphaWallet/keychain-swift.git', :commit=> 'b797d40a9d08ec509db4335140cf2259b226e6a2'
  pod 'SwiftLint', '0.40.3'
  pod 'RealmSwift', '5.5.1'
  pod 'Moya', '~> 10.0.1'
  pod 'JavaScriptKit'
  pod 'CryptoSwift', '~> 1.4'
  pod 'Kingfisher', '5.15.7'
  pod 'AlphaWalletWeb3Provider', :git=>'https://github.com/AlphaWallet/AlphaWallet-web3-provider', :commit => '9a4496d02b7ddb2f6307fd0510d8d7c9fcef9870'
  pod 'TrezorCrypto', :git=>'https://github.com/AlphaWallet/trezor-crypto-ios.git', :commit => '50c16ba5527e269bbc838e80aee5bac0fe304cc7'
  pod 'TrustKeystore', :git => 'https://github.com/alpha-wallet/trust-keystore.git', :commit => 'c0bdc4f6ffc117b103e19d17b83109d4f5a0e764'
  pod 'SwiftyJSON', '5.0.0'
  pod 'web3swift', :git => 'https://github.com/AlphaWallet/web3swift.git', :commit=> 'cce12b1c421f18b5768e5249a8343932737a51fe'
  pod 'SAMKeychain'
  pod 'PromiseKit/CorePromise'
  pod 'PromiseKit/Alamofire'
  pod "Kanna", :git => 'https://github.com/tid-kijyun/Kanna.git', :commit => '06a04bc28783ccbb40efba355dee845a024033e8'
  pod 'TrustWalletCore', '2.6.34'
  pod 'AWSSNS', '2.18.0'
  pod 'Mixpanel-swift', '2.8.0'
  pod 'UnstoppableDomainsResolution', '0.1.6'
  pod 'BlockiesSwift'
  pod 'PaperTrailLumberjack/Swift'
  pod 'WalletConnectSwift', :git => 'https://github.com/WalletConnect/WalletConnectSwift.git'
  pod 'AssistantKit'
  # pod 'AWSCognito'
  pod 'Charts'
  pod 'CocoaLumberjack', '3.7.0'
  pod 'AlphaWalletAddress', :path => 'modules/AlphaWalletAddress'
  pod 'Apollo'

  target 'AlphaWalletTests' do
      inherit! :search_paths
      # Pods for testing
      pod 'iOSSnapshotTestCase', '6.2.0'
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      #config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      config.build_settings["ARCHS[sdk=iphonesimulator*]"] = "x86_64"
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
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0';
    end
  end
end
