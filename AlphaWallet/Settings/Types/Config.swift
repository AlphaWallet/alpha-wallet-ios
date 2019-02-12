// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import ObjectiveC
import TrustKeystore
import web3swift

struct Config {
    struct Keys {
        static let chainID = "chainID"
        static let isCryptoPrimaryCurrency = "isCryptoPrimaryCurrency"
        static let isDebugEnabled = "isDebugEnabled"
        static let currencyID = "currencyID"
        static let dAppBrowser = "dAppBrowser"
        static let walletAddressesAlreadyPromptedForBackUp = "walletAddressesAlreadyPromptedForBackUp "
        static let locale = "locale"
    }

    let defaults: UserDefaults

    init(
        defaults: UserDefaults = UserDefaults.standard
    ) {
        self.defaults = defaults
    }

    var currency: Currency {
        get {
            //If it is saved currency
            if let currency = defaults.string(forKey: Keys.currencyID) {
                return Currency(rawValue: currency)!
            }
            //If ther is not saved currency try to use user local currency if it is supported.
            let availableCurrency = Currency.allValues.first { currency in
                return currency.rawValue == Locale.current.currencySymbol
            }
            if let isAvailableCurrency = availableCurrency {
                return isAvailableCurrency
            }
            //If non of the previous is not working return USD.
            return Currency.USD
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.currencyID) }
    }

    var chainID: Int {
        get {
            let id = defaults.integer(forKey: Keys.chainID)
            guard id > 0 else { return RPCServer.main.chainID }
            return id
        }
        set { defaults.set(newValue, forKey: Keys.chainID) }
    }

    var locale: String? {
        get { return defaults.string(forKey: Keys.locale) }
        set {
            let preferenceKeyForOverridingInAppLanguage = "AppleLanguages"
            if let locale = newValue {
                defaults.set(newValue, forKey: Keys.locale)
                defaults.set([locale], forKey: preferenceKeyForOverridingInAppLanguage)
            } else {
                defaults.removeObject(forKey: Keys.locale)
                defaults.removeObject(forKey: preferenceKeyForOverridingInAppLanguage)
            }
            defaults.synchronize()
            LiveLocaleSwitcherBundle.switchLocale(to: newValue)
        }
    }

    var isCryptoPrimaryCurrency: Bool {
        get { return defaults.bool(forKey: Keys.isCryptoPrimaryCurrency) }
        set { defaults.set(newValue, forKey: Keys.isCryptoPrimaryCurrency) }
    }

    var server: RPCServer {
        return RPCServer(chainID: chainID)
    }

    var rpcURL: URL {
        let urlString: String = {
            switch server {
            case .main: return "https://mainnet.infura.io/llyrtzQ3YhkdESt2Fzrk"
            case .classic: return "https://web3.gastracker.io"
            case .callisto: return "https://callisto.network/" //TODO Add endpoint
            case .kovan: return "https://kovan.infura.io/llyrtzQ3YhkdESt2Fzrk"
            case .ropsten: return "https://ropsten.infura.io/llyrtzQ3YhkdESt2Fzrk"
            case .rinkeby: return "https://rinkeby.infura.io/llyrtzQ3YhkdESt2Fzrk"
            case .poa: return "https://core.poa.network"
            case .sokol: return "https://sokol.poa.network"
            case .xDai: return "https://dai.poa.network"
            case .custom(let custom):
                return custom.endpoint
            }
        }()
        return URL(string: urlString)!
    }

    var transactionInfoEndpoints: URL {
        let urlString: String = {
            switch server {
            case .main: return "https://api.etherscan.io"
            case .classic: return "https://blockscout.com/etc/mainnet/api"
            case .callisto: return "https://callisto.trustwalletapp.com"
            case .kovan: return "https://api-kovan.etherscan.io"
            case .ropsten: return "https://api-ropsten.etherscan.io"
            case .rinkeby: return "https://api-rinkeby.etherscan.io"
            case .poa: return "https://blockscout.com/poa/core/api"
            case .xDai: return "https://blockscout.com/poa/dai/api"
            case .sokol: return "https://blockscout.com/poa/sokol/api"
            case .custom:
                return "" // Enable? make optional
            }
        }()
        return URL(string: urlString)!
    }

    var ensRegistrarContract: EthereumAddress {
        switch server {
        case .main: return Constants.ENSRegistrarAddress
        case .ropsten: return Constants.ENSRegistrarRopsten
        case .rinkeby: return Constants.ENSRegistrarRinkeby
        case .xDai: return Constants.ENSRegistrarXDAI
        default: return Constants.ENSRegistrarAddress
        }
    }

    let priceInfoEndpoints = URL(string: "https://api.coinmarketcap.com")!

    var walletAddressesAlreadyPromptedForBackUp: [String] {
        if let addresses = defaults.array(forKey: Keys.walletAddressesAlreadyPromptedForBackUp) {
            return addresses as! [String]
        } else {
            return []
        }
    }

    ///Debugging flag. Set to false to disable auto fetching prices, etc to cut down on network calls
    let isAutoFetchingDisabled = false

    func addToWalletAddressesAlreadyPromptedForBackup(address: String) {
        var addresses: [String]
        if let value = defaults.array(forKey: Keys.walletAddressesAlreadyPromptedForBackUp) {
            addresses = value as! [String]
        } else {
            addresses = [String]()
        }
        addresses.append(address)
        defaults.setValue(addresses, forKey: Keys.walletAddressesAlreadyPromptedForBackUp)
    }

    func isWalletAddressAlreadyPromptedForBackUp(address: String) -> Bool {
        if let value = defaults.array(forKey: Keys.walletAddressesAlreadyPromptedForBackUp) {
            let addresses = value as! [String]
            return addresses.contains(address)
        } else {
            return false
        }
    }

}
