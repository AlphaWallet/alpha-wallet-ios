# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'AlphaWalletAddress' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for AlphaWalletAddress
  pod 'TrustKeystore', :git => 'https://github.com/alpha-wallet/trust-keystore.git', :commit => 'c0bdc4f6ffc117b103e19d17b83109d4f5a0e764'
  pod 'TrustWalletCore'

  target 'AlphaWalletAddressTests' do
    # Pods for testing
  end

  post_install do |installer|
    installer.pods_project.targets.each do |target|

      if ['TrustKeystore'].include? target.name
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Owholemodule'
        end
      end
    end
  end
end
