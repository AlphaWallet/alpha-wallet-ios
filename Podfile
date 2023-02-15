platform :ios, '13.0'
inhibit_all_warnings!
source 'https://cdn.cocoapods.org/'

target 'AlphaWallet' do
  use_frameworks!
  pod 'BigInt', '~> 3.1'
  pod 'R.swift'
  pod 'MBProgressHUD'
  pod 'StatefulViewController'
  pod 'QRCodeReaderViewController', :git=>'https://github.com/AlphaWallet/QRCodeReaderViewController.git', :commit=>'30d1a2a7d167d0d207ae0ae3a4d81bcf473d7a65'
  pod 'KeychainSwift', :git=>'https://github.com/AlphaWallet/keychain-swift.git', :commit=> 'b797d40a9d08ec509db4335140cf2259b226e6a2'
  pod 'Kingfisher', '~> 7.0'
  pod 'AlphaWalletWeb3Provider', :git=>'https://github.com/AlphaWallet/AlphaWallet-web3-provider', :commit => '9a4496d02b7ddb2f6307fd0510d8d7c9fcef9870'
  pod 'TrezorCrypto', :git=>'https://github.com/AlphaWallet/trezor-crypto-ios.git', :commit => '50c16ba5527e269bbc838e80aee5bac0fe304cc7'
  pod 'TrustKeystore', :git => 'https://github.com/AlphaWallet/latest-keystore-snapshot', :commit => 'c0bdc4f6ffc117b103e19d17b83109d4f5a0e764'
  pod 'SAMKeychain'
  pod 'PromiseKit/CorePromise'
  pod 'Kanna', :git => 'https://github.com/tid-kijyun/Kanna.git', :commit => '06a04bc28783ccbb40efba355dee845a024033e8'
  pod 'Mixpanel-swift', '~> 3.1'
  pod 'EthereumABI', :git => 'https://github.com/AlphaWallet/EthereumABI.git', :commit => '877b77e8e7cbc54ab0712d509b74fec21b79d1bb'
  pod 'Charts'
  pod 'AlphaWalletAddress', :path => '.'
  pod 'AlphaWalletCore', :path => '.'
  pod 'AlphaWalletGoBack', :path => '.'
  pod 'AlphaWalletENS', :path => '.'
  pod 'AlphaWalletLogger', :path => '.'
  pod 'AlphaWalletOpenSea', :path => '.'
  pod 'AlphaWalletFoundation', :path => '.'
  pod 'AlphaWalletTrackAPICalls', :path => '.'
  pod 'AlphaWalletWeb3', :path => '.'
  pod 'AlphaWalletShareExtensionCore', :path => '.'
  pod 'MailchimpSDK'
  pod 'xcbeautify'
  pod 'FloatingPanel'
  pod 'IQKeyboardManager'

  pod 'SwiftLint', '0.50.3', :configuration => 'Debug'
  pod 'SwiftFormat/CLI', '~> 0.49', :configuration => 'Debug'

  pod 'WalletConnectSwiftV2', :git => 'https://github.com/WalletConnect/WalletConnectSwiftV2.git', :tag => '1.3.1'
  pod 'WalletConnectSwiftV2/Web3Wallet', :git => 'https://github.com/WalletConnect/WalletConnectSwiftV2.git', :tag => '1.3.1'
  pod 'FirebaseCrashlytics', '8.10.0'
  pod 'WalletConnectSwift', :git => 'https://github.com/AlphaWallet/WalletConnectSwift.git', :branch => 'alphaWallet'
  pod 'Starscream', '3.1.1'
  
  target 'AlphaWalletTests' do
      inherit! :search_paths
      # Pods for testing
      pod 'iOSSnapshotTestCase', '6.2.0'
  end


end

target 'AlphaWalletShare' do
  use_frameworks!
  inherit! :search_paths

  pod 'AlphaWalletShareExtensionCore', :path => '.'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
    
    if ['MailchimpSDK'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
        config.build_settings["ARCHS[sdk=iphonesimulator*]"] = "x86_64"
      end
    end

    if ['TrustKeystore'].include? target.name
      target.build_configurations
        .reject {|e| e.debug?}
        .each do |config|
          config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Owholemodule'
        end

      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
      end
    end

    if ['Result', 'SwiftyXMLParser', 'JSONRPCKit', 'Starscream'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
      end
    end

    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0';
    end

    target.build_configurations
      .filter {|e| e.debug?}
      .each do |config|
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      end
      
    target.build_configurations.each do |config|
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
     end
  end
end
