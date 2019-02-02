platform :ios, '10.0'
inhibit_all_warnings!
source 'https://github.com/CocoaPods/Specs.git'

target 'AlphaWallet' do
  use_frameworks!

  pod 'BigInt', '~> 3.0'
  pod 'R.swift'
  pod 'JSONRPCKit', '~> 2.0.0'
  pod 'APIKit'
  pod 'Eureka', '~> 4.3'
  pod 'MBProgressHUD'
  pod 'StatefulViewController'
  pod 'QRCodeReaderViewController', :git=>'https://github.com/yannickl/QRCodeReaderViewController.git', :branch=>'master'
  pod 'KeychainSwift'
  pod 'SwiftLint'
  pod 'SeedStackViewController'
  pod 'RealmSwift', '~> 3.9'
  pod 'Moya', '~> 10.0.1'
  pod 'JavaScriptKit'
  pod 'CryptoSwift'
  pod 'SwiftyXMLParser', :git => 'https://github.com/yahoojapan/SwiftyXMLParser.git'
  pod 'Kingfisher', '~> 4.0'
  pod 'AlphaWalletWeb3Provider', :git=>'https://github.com/AlphaWallet/AlphaWallet-web3-provider', :commit => 'f25206c50009d1eb922c3cc8c0ba91594155e8b6'
  pod 'TrezorCrypto', :git=>'https://github.com/AlphaWallet/trezor-crypto-ios.git', :commit => '50c16ba5527e269bbc838e80aee5bac0fe304cc7'
  pod 'TrustKeystore', :git => 'https://github.com/alpha-wallet/trust-keystore.git', :commit => '9abdc1a63f1baf17facb26a3e049b5e335a95816'
  pod 'SwiftyJSON'
  pod 'web3swift', :git => 'https://github.com/alpha-wallet/web3swift.git', :commit => '2b3c5ee878212ce70768568def7e727f0f1ebf86'
  pod 'SAMKeychain'
  pod 'PromiseKit/CorePromise'
  pod 'PromiseKit/Alamofire'
  pod "Macaw", :git => 'https://github.com/alpha-wallet/Macaw.git', :commit => 'c13e70e63dd1a2554b59e0aa75c12b93e2ee9dd8'
  pod 'Kanna', '~> 4.0.0'
  pod 'BRCybertron', :git => 'https://github.com/AlphaWallet/BRCybertron.git', :submodules => true, :commit => 'a79310de3e4b7d35bc624ce90c3c701411ef516e'
  pod 'AWSSNS'
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
    if ['JSONRPCKit'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '3.0'
      end
    end
    if ['TrustKeystore'].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Owholemodule'
      end
    end
    if [
        'APIKit',
        'Kingfisher',
        'Macaw',
        'R.swift.Library',
        'RealmSwift',
        'Result',
        'SeedStackViewController',
        'SwiftyXMLParser'
    ].include? target.name
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4'
      end
    end
  end
end

