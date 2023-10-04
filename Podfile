platform :ios, '13.0'
inhibit_all_warnings!
source 'https://cdn.cocoapods.org/'

target 'AlphaWallet' do
  use_frameworks!
  pod 'BigInt', '~> 3.1'
  pod 'R.swift'
  pod 'MBProgressHUD'
  pod 'StatefulViewController'
  pod 'QRCodeReaderViewController', :git=>'https://github.com/AlphaWallet/QRCodeReaderViewController.git', :commit=>'09da2d4b835589972ecacd022a75bc27b2c1d1bd'
  pod 'KeychainSwift', :git=>'https://github.com/AlphaWallet/keychain-swift.git', :commit=> 'b797d40a9d08ec509db4335140cf2259b226e6a2'
  pod 'Kingfisher', '~> 7.6.2'
  pod 'AlphaWalletWeb3Provider', :git=>'https://github.com/AlphaWallet/AlphaWallet-web3-provider', :commit => 'bdb38b06eeedeb4ca1e32d3ecd81783b5116ae68'
  pod 'TrezorCrypto', :git=>'https://github.com/AlphaWallet/trezor-crypto-ios.git', :commit => '50c16ba5527e269bbc838e80aee5bac0fe304cc7'
  pod 'TrustKeystore', :git => 'https://github.com/AlphaWallet/latest-keystore-snapshot', :commit => 'c0bdc4f6ffc117b103e19d17b83109d4f5a0e764'
  pod 'SAMKeychain'
  pod 'PromiseKit/CorePromise'
  pod 'Kanna', :git => 'https://github.com/tid-kijyun/Kanna.git', :commit => '06a04bc28783ccbb40efba355dee845a024033e8'
  pod 'Mixpanel-swift', '~> 3.1'
  pod 'EthereumABI', :git => 'https://github.com/AlphaWallet/EthereumABI.git', :commit => '877b77e8e7cbc54ab0712d509b74fec21b79d1bb'
  pod 'Charts'
  pod 'AlphaWalletABI', :path => '.'
  pod 'AlphaWalletAddress', :path => '.'
  pod 'AlphaWalletAttestation', :path => '.'
  pod 'AlphaWalletBrowser', :path => '.'
  pod 'AlphaWalletCore', :path => '.'
  pod 'AlphaWalletGoBack', :path => '.'
  pod 'AlphaWalletENS', :path => '.'
  pod 'AlphaWalletHardwareWallet', :path => '.'
  pod 'AlphaWalletLogger', :path => '.'
  pod 'AlphaWalletOpenSea', :path => '.'
  pod 'AlphaWalletFoundation', :path => '.'
  pod 'AlphaWalletTrackAPICalls', :path => '.'
  pod 'AlphaWalletWeb3', :path => '.'
  pod 'AlphaWalletShareExtensionCore', :path => '.'
  pod 'AlphaWalletTrustWalletCoreExtensions', :path => '.'
  pod 'AlphaWalletNotifications', :path => '.'
  pod 'AlphaWalletTokenScript', :path => '.'
  pod 'MailchimpSDK'
  pod 'xcbeautify'
  pod 'FloatingPanel'
  pod 'IQKeyboardManager'

  pod 'SwiftLint', '0.50.3', :configuration => 'Debug'
  pod 'SwiftFormat/CLI', '~> 0.49', :configuration => 'Debug'
  pod 'Firebase/Crashlytics'
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

    #Work around for build warning:
    #    Run script build phase 'Create Symlinks to Header Folders' will be run during every build because it does not specify any outputs. To address this warning, either add output dependencies to the script phase, or configure it to run in every build by unchecking "Based on dependency analysis" in the script phase.
    #From https://github.com/realm/realm-swift/issues/7957#issuecomment-1248556797
    if ['Realm'].include? target.name
      create_symlink_phase = target.shell_script_build_phases.find { |x| x.name == 'Create Symlinks to Header Folders' }
      create_symlink_phase.always_out_of_date = "1"
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
