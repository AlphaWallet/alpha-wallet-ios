// Copyright Stormbird PTE. LTD.

import Foundation
import ObjectiveC
import web3swift
import Combine

struct Config {
    struct Development {
        let shouldReadClipboardForWalletConnectUrl = false
        let shouldNotSendTransactions = false
        ///Useful to reduce network calls
        let isAutoFetchingDisabled = false
        ///Should only be used to allow users to take paths where the current wallet is real, not watched, e.g sign buttons are enabled. Some of those actions will fail, understandably. Should not display a watch wallet as if it is a real wallet though
        let shouldPretendIsRealWallet = false
        let isOpenSeaFetchingDisabled = false
        let isRunLoopThreadLoggingEnabled = false
    }

    let development = Development()

    //TODO `currency` was originally a instance-side property, but was refactored out. Maybe better if it it's moved elsewhere
    static func getCurrency() -> Currency {
        let defaults = UserDefaults.standardOrForTests

        //If it is saved currency
        if let currency = defaults.string(forKey: Keys.currencyID) {
            return Currency(rawValue: currency)!
        }
        //If the is not saved currency try to use user local currency if it is supported.
        let availableCurrency = Currency.allValues.first { currency in
            return currency.rawValue == Config.locale.currencySymbol
        }
        if let isAvailableCurrency = availableCurrency {
            return isAvailableCurrency
        }
        //If non of the previous is not working return USD.
        return Currency.USD
    }

    static func setCurrency(_ currency: Currency) {
        let defaults = UserDefaults.standardOrForTests
        defaults.set(currency.rawValue, forKey: Keys.currencyID)
    }

    //TODO `locale` was originally a instance-side property, but was refactored out. Maybe better if it it's moved elsewhere
    static func getLocale() -> String? {
        let defaults = UserDefaults.standardOrForTests
        return defaults.string(forKey: Keys.locale)
    }

    static var locale: Locale {
        if let identifier = getLocale(), isRunningTests() {
            return Locale(identifier: identifier)
        } else {
            return Locale.current
        }
    }

    static func setLocale(_ locale: AppLocale) {
        setLocale(locale.id)

        EtherNumberFormatter.full = .createFullEtherNumberFormatter()
        EtherNumberFormatter.short = .createShortEtherNumberFormatter()
        EtherNumberFormatter.shortPlain = .createShortPlainEtherNumberFormatter()
        EtherNumberFormatter.plain = .createPlainEtherNumberFormatter()
    }

    static func setLocale(_ locale: String?) {
        let defaults = UserDefaults.standardOrForTests
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
    static func setChainId(_ chainId: Int, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        defaults.set(chainId, forKey: Keys.chainID)
    }

    //TODO Only Dapp browser uses this
    static func getChainId(defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int {
        let id = defaults.integer(forKey: Keys.chainID)
        guard id > 0 else { return RPCServer.main.chainID }
        return id
    }

    private static func generateLastFetchedErc20InteractionBlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenErc20BlockNumber)-\(wallet.eip55String)"
    }

    private static func generateLastFetchedErc721InteractionBlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenErc721BlockNumber)-\(wallet.eip55String)"
    }

    private static func generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenErc20BlockNumber)-\(wallet.eip55String)"
    }

    private static func generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber)-\(wallet.eip55String)"
    }

    static func setLastFetchedErc20InteractionBlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet))
    }

    static func getLastFetchedErc20InteractionBlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    static func setLastFetchedErc721InteractionBlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedErc721InteractionBlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedErc721InteractionBlockNumberKey(wallet))
    }

    static func getLastFetchedErc721InteractionBlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedErc721InteractionBlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    static func setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet))
    }

    static func getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    static func setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet))
    }

    static func getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    struct Keys {
        static let chainID = "chainID"
        static let isCryptoPrimaryCurrency = "isCryptoPrimaryCurrency"
        static let currencyID = "currencyID"
        static let dAppBrowser = "dAppBrowser"
        //There *is* a trailing space in the key
        static let walletAddressesAlreadyPromptedForBackUp = "walletAddressesAlreadyPromptedForBackUp "
        static let locale = "locale"
        static let enabledServers = "enabledChains"
        static let lastFetchedErc20InteractionBlockNumber = "lastFetchedErc20InteractionBlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenErc20BlockNumber = "lastFetchedAutoDetectedTransactedTokenErc20BlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenErc721BlockNumber = "lastFetchedAutoDetectedTransactedTokenErc721BlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber = "lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber"
        static let walletNames = "walletNames"
        //We don't write to this key anymore as we support more than 1 service provider. Reading this key only for legacy reasons
        static let usePrivateNetwork = "usePrivateNetworkKey"
        static let privateNetworkProvider = "privateNetworkProvider"
        static let customRpcServers = "customRpcServers"
        static let homePageURL = "homePageURL"
        static let sendAnalyticsEnabled = "sendAnalyticsEnabled"
    }

    let defaults: UserDefaults
    var isSendAnalyticsEnabled: Bool {
        sendAnalyticsEnabled ?? false
    }

    var sendAnalyticsEnabled: Bool? {
        get {
            guard Features.default.isAvailable(.isAnalyticsUIEnabled) else { return nil }
            guard let value = defaults.value(forKey: Keys.sendAnalyticsEnabled) as? Bool else {
                return nil
            }

            return value
        }
        set {
            guard Features.default.isAvailable(.isAnalyticsUIEnabled) else {
                defaults.removeObject(forKey: Keys.sendAnalyticsEnabled)
                return
            }

            defaults.set(newValue, forKey: Keys.sendAnalyticsEnabled)
        }
    }

    var sendPrivateTransactionsProvider: SendPrivateTransactionsProvider? {
        get {
            guard Features.default.isAvailable(.isUsingPrivateNetwork) else { return nil }
            if defaults.bool(forKey: Keys.usePrivateNetwork) {
                //Default, for legacy reasons
                return .ethermine
            } else {
                let s = defaults.string(forKey: Keys.privateNetworkProvider)
                return s.flatMap { SendPrivateTransactionsProvider(rawValue: $0) }
            }
        }
        set {
            guard Features.default.isAvailable(.isUsingPrivateNetwork) else { return }
            defaults.set(newValue?.rawValue, forKey: Keys.privateNetworkProvider)
        }
    }

    var enabledServers: [RPCServer] {
        get {
            if let chainIds = defaults.array(forKey: Keys.enabledServers) as? [Int] {
                if chainIds.isEmpty {
                    //TODO remote log. Why is this possible? Note it's not nil (which is possible for new installs)
                    return Constants.defaultEnabledServers
                } else {
                    let servers: [RPCServer] = chainIds.map { .init(chainID: $0) }.filter { $0.conflictedServer == nil }
                    //TODO remove filter after some time as every user should have upgraded and no longer has a mix of mainnet and testnet enabled at the same time. We could have done this filtering one-time per wallet outside of here, but doing it here is more localized
                    if servers.contains(where: { $0.isTestnet }) && servers.contains(where: { !$0.isTestnet }) {
                        let filteredServers = servers.filter { !$0.isTestnet }
                        var configForEditing = self
                        configForEditing.enabledServers = filteredServers
                        return filteredServers
                    } else {
                        return servers
                    }
                }
            } else {
                return Constants.defaultEnabledServers
            }
        }
        set {
            let chainIds = newValue.map { $0.chainID }
            defaults.set(chainIds, forKey: Keys.enabledServers)

            Self.enabledServersSubject.send(newValue)
        }
    }

    var customRpcServersJson: String? {
        get {
            return defaults.string(forKey: Keys.customRpcServers)
        }
        set {
            defaults.set(newValue, forKey: Keys.customRpcServers)
        }
    }

    var homePageURL: URL? {
        get {
            return defaults.string(forKey: Keys.homePageURL).flatMap { URL(string: $0) }
        }
        set {
            defaults.set(newValue?.absoluteString, forKey: Keys.homePageURL)
        }
    }

    var enabledServersPublisher: AnyPublisher<[RPCServer], Never> {
        Self.enabledServersSubject
            .filter { !$0.isEmpty }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    //NOTE: keep static while not reduce amount of created instances of `Config`, need to reduce up it to using single instance of Config
    private static var enabledServersSubject: CurrentValueSubject<[RPCServer], Never> = .init([])

    init(defaults: UserDefaults = UserDefaults.standardOrForTests) {
        self.defaults = defaults
    }

    var oldWalletAddressesAlreadyPromptedForBackUp: [String] {
        //We hard code the key here because it's used for migrating off the old value, there should be no reason why this key will change in the next line
        //There *is* a trailing space in the key
        if let addresses = defaults.array(forKey: "walletAddressesAlreadyPromptedForBackUp ") {
            return addresses as! [String]
        } else {
            return []
        }
    }

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

    func anyEnabledServer() -> RPCServer {
        let servers = enabledServers
        if servers.contains(.main) {
            return .main
        } else {
            return servers.first!
        }
    }
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

    func removeAllWalletNames() {
        defaults.removeObject(forKey: Keys.walletNames)
    }
}

extension Config {

    private static func notificationKey(for transaction: TransactionInstance) -> String {
        String(format: "%@-%d", transaction.id, transaction.chainId)
    }

    private static func notificationsStorageKey(wallet: Wallet) -> String {
        return "presentedNotifications-\(wallet.address.eip55String)"
    }

    func hasScheduledNotification(for transaction: TransactionInstance, in wallet: Wallet) -> Bool {
        let key = Config.notificationKey(for: transaction)
        return notifications(wallet: wallet).contains(key)
    }

    private func notifications(wallet: Wallet) -> [String] {
        let storageKey = Config.notificationsStorageKey(wallet: wallet)
        if let values = defaults.array(forKey: storageKey) {
            return values as! [String]
        } else {
            return []
        }
    }

    func markScheduledNotification(transaction: TransactionInstance, in wallet: Wallet) {
        let key = Config.notificationKey(for: transaction)
        let notifications = notifications(wallet: wallet)
        let updatedNotifications = Array(Set(notifications + [key]))

        let storageKey = Config.notificationsStorageKey(wallet: wallet)
        defaults.set(updatedNotifications, forKey: storageKey)
    }

    func removeAllNotifications(for wallet: Wallet) {
        let storageKey = Config.notificationsStorageKey(wallet: wallet)
        defaults.removeObject(forKey: storageKey)
    }
}
