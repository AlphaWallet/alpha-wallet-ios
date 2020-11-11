// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import ObjectiveC
import web3swift

struct Config {
    //TODO `currency` was originally a instance-side property, but was refactored out. Maybe better if it it's moved elsewhere
    static func getCurrency() -> Currency {
        let defaults = UserDefaults.standard

        //If it is saved currency
        if let currency = defaults.string(forKey: Keys.currencyID) {
            return Currency(rawValue: currency)!
        }
        //If the is not saved currency try to use user local currency if it is supported.
        let availableCurrency = Currency.allValues.first { currency in
            return currency.rawValue == Locale.current.currencySymbol
        }
        if let isAvailableCurrency = availableCurrency {
            return isAvailableCurrency
        }
        //If non of the previous is not working return USD.
        return Currency.USD
    }

    static func setCurrency(_ currency: Currency) {
        let defaults = UserDefaults.standard
        defaults.set(currency.rawValue, forKey: Keys.currencyID)
    }

    //TODO `locale` was originally a instance-side property, but was refactored out. Maybe better if it it's moved elsewhere
    static func getLocale() -> String? {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: Keys.locale)
    }

    static func setLocale(_ locale: AppLocale) {
        setLocale(locale.id)
    }

    static func setLocale(_ locale: String?) {
        let defaults = UserDefaults.standard
        let preferenceKeyForOverridingInAppLanguage = "AppleLanguages"
        if let locale = locale {
            defaults.set(locale, forKey: Keys.locale)
            defaults.set([locale], forKey: preferenceKeyForOverridingInAppLanguage)
        } else {
            defaults.removeObject(forKey: Keys.locale)
            defaults.removeObject(forKey: preferenceKeyForOverridingInAppLanguage)
        }
        defaults.synchronize()
        LiveLocaleSwitcherBundle.switchLocale(to: locale)
    }

    //TODO Only Dapp browser uses this. Shall we move it?
    static func setChainId(_ chainId: Int, defaults: UserDefaults = UserDefaults.standard) {
        defaults.set(chainId, forKey: Keys.chainID)
    }

    static func getChainId(defaults: UserDefaults = UserDefaults.standard) -> Int {
        let id = defaults.integer(forKey: Keys.chainID)
        guard id > 0 else { return RPCServer.main.chainID }
        return id
    }

    private static func generateLastFetchedErc20InteractionBlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenErc20BlockNumber)-\(wallet.eip55String)"
    }

    private static func generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenErc20BlockNumber)-\(wallet.eip55String)"
    }

    private static func generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber)-\(wallet.eip55String)"
    }

    static func setLastFetchedErc20InteractionBlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standard) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet))
    }

    static func getLastFetchedErc20InteractionBlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standard) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    static func setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standard) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet))
    }

    static func getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standard) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    static func setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standard) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet))
    }

    static func getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standard) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    struct Keys {
        static let chainID = "chainID"
        static let isCryptoPrimaryCurrency = "isCryptoPrimaryCurrency"
        static let isDebugEnabled = "isDebugEnabled"
        static let currencyID = "currencyID"
        static let dAppBrowser = "dAppBrowser"
        static let walletAddressesAlreadyPromptedForBackUp = "walletAddressesAlreadyPromptedForBackUp "
        static let locale = "locale"
        static let enabledServers = "enabledChains"
        static let lastFetchedErc20InteractionBlockNumber = "lastFetchedErc20InteractionBlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenErc20BlockNumber = "lastFetchedAutoDetectedTransactedTokenErc20BlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber = "lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber"
        static let walletNames = "walletNames"
    }

    let defaults: UserDefaults

    var enabledServers: [RPCServer] {
        get {
            if let chainIds = defaults.array(forKey: Keys.enabledServers) as? [Int] {
                return chainIds.map { .init(chainID: $0) }
            } else {
                return Constants.defaultEnabledServers
            }
        }
        set {
            let chainIds = newValue.map { $0.chainID }
            defaults.set(chainIds, forKey: Keys.enabledServers)
        }
    }

    var server: RPCServer {
        let chainId = Config.getChainId()
        if let server = enabledServers.first(where: { $0.chainID == chainId }) {
            return server
        } else {
            return .main
        }
    }

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    let priceInfoEndpoints = URL(string: "https://api.coingecko.com")!

    var oldWalletAddressesAlreadyPromptedForBackUp: [String] {
        //We hard code the key here because it's used for migrating off the old value, there should be no reason why this key will change in the next line
        if let addresses = defaults.array(forKey: "walletAddressesAlreadyPromptedForBackUp ") {
            return addresses as! [String]
        } else {
            return []
        }
    }

    ///Debugging flag. Set to false to disable auto fetching prices, etc to cut down on network calls
    let isAutoFetchingDisabled = false

    func addToWalletAddressesAlreadyPromptedForBackup(address: AlphaWallet.Address) {
        var addresses: [String]
        if let value = defaults.array(forKey: Keys.walletAddressesAlreadyPromptedForBackUp) {
            addresses = value as! [String]
        } else {
            addresses = [String]()
        }
        addresses.append(address.eip55String)
        defaults.setValue(addresses, forKey: Keys.walletAddressesAlreadyPromptedForBackUp)
    }

    let oneInch = URL(string: "https://api.1inch.exchange")!
}

extension Config {
    var walletNames: [AlphaWallet.Address: String] {
        if let names = defaults.dictionary(forKey: Keys.walletNames) as? [String: String] {
            let tuples = names.compactMap { key, value -> (AlphaWallet.Address, String)? in
                guard let address = AlphaWallet.Address(string: key) else { return nil }
                return (address, value)
            }
            return Dictionary(uniqueKeysWithValues: tuples)
        } else {
            return .init()
        }
    }

    private func setWalletNames(walletNames: [AlphaWallet.Address: String]) {
        let names = walletNames.map { ($0.key.eip55String, $0.value) }
        let dictionary = Dictionary(names, uniquingKeysWith: { $1 })
        defaults.set(dictionary, forKey: Keys.walletNames)
    }

    func saveWalletName(_ walletName: String, forAddress address: AlphaWallet.Address) {
        let walletName = walletName.trimmed
        guard !walletName.isEmpty else { return }
        var names = walletNames
        names[address] = walletName
        setWalletNames(walletNames: names)
    }

    func deleteWalletName(forAccount address: AlphaWallet.Address) {
        var names = walletNames
        names[address] = nil
        setWalletNames(walletNames: names)
    }
}
