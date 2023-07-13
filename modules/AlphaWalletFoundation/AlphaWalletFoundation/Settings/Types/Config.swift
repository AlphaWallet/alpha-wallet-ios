// Copyright Stormbird PTE. LTD.

import Foundation
import ObjectiveC
import Combine

public struct Config {
    public struct Development {
        public let shouldReadClipboardForWalletConnectUrl = false
        public let shouldNotSendTransactions = false
        ///Useful to reduce network calls
        public let isAutoFetchingDisabled = false
        ///Should only be used to allow users to take paths where the current wallet is real, not watched, e.g sign buttons are enabled. Some of those actions will fail, understandably. Should not display a watch wallet as if it is a real wallet though
        public let shouldPretendIsRealWallet = false
        public let isOpenSeaFetchingDisabled = false
        public let isRunLoopThreadLoggingEnabled = false
        public let shouldReadClipboardForQRCode = false

        public init() {}
    }

    public let development = Development()

    public var currency: Currency {
        get {
            if let currency = defaults.string(forKey: Keys.currency) {
                return Currency(rawValue: currency)!
            } else if let currency = Currency.allCases.first(where: { $0.code == Config.locale.currencySymbol }) {
                return currency
            } else {
                return Currency.default
            }
        }
        set {
            defaults.set(newValue.code, forKey: Keys.currency)
        }
    }

    //TODO `locale` was originally a instance-side property, but was refactored out. Maybe better if it it's moved elsewhere
    public static func getLocale() -> String? {
        let defaults = UserDefaults.standardOrForTests
        return defaults.string(forKey: Keys.locale)
    }

    public static var locale: Locale {
        if let identifier = getLocale(), isRunningTests() {
            return Locale(identifier: identifier)
        } else {
            return Locale.current
        }
    }

    public static func setLocale(_ locale: AppLocale) {
        setLocale(locale.id)

        EtherNumberFormatter.full = .createFullEtherNumberFormatter()
        EtherNumberFormatter.short = .createShortEtherNumberFormatter(maximumFractionDigits: Constants.etherFormatterFractionDigits)
        EtherNumberFormatter.shortPlain = .createShortPlainEtherNumberFormatter(maximumFractionDigits: Constants.etherFormatterFractionDigits)
        EtherNumberFormatter.plain = .createPlainEtherNumberFormatter()
    }

    public static func setLocale(_ locale: String?) {
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
    public static func setChainId(_ chainId: Int, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        defaults.set(chainId, forKey: Keys.chainID)
    }

    //TODO Only Dapp browser uses this
    public static func getChainId(defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int {
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

    private static func generateLastFetchedErc1155InteractionBlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenErc1155BlockNumber)-\(wallet.eip55String)"
    }

    private static func generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenErc20BlockNumber)-\(wallet.eip55String)"
    }

    private static func generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(_ wallet: AlphaWallet.Address) -> String {
        "\(Keys.lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber)-\(wallet.eip55String)"
    }

    public static func setLastFetchedErc20InteractionBlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet))
    }

    public static func getLastFetchedErc20InteractionBlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedErc20InteractionBlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    public static func setLastFetchedErc721InteractionBlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedErc721InteractionBlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedErc721InteractionBlockNumberKey(wallet))
    }

    public static func setLastFetchedErc1155InteractionBlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedErc1155InteractionBlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedErc1155InteractionBlockNumberKey(wallet))
    }

    public static func getLastFetchedErc721InteractionBlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedErc721InteractionBlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    public static func getLastFetchedErc1155InteractionBlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedErc1155InteractionBlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    public static func setLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet))
    }

    public static func getLastFetchedAutoDetectedTransactedTokenErc20BlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenErc20BlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    public static func setLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(_ blockNumber: Int, server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) {
        var dictionary: [String: NSNumber] = (defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet)) as? [String: NSNumber]) ?? .init()
        dictionary["\(server.chainID)"] = NSNumber(value: blockNumber)
        defaults.set(dictionary, forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet))
    }

    public static func getLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber(_ server: RPCServer, wallet: AlphaWallet.Address, defaults: UserDefaults = UserDefaults.standardOrForTests) -> Int? {
        guard let dictionary = defaults.value(forKey: generateLastFetchedAutoDetectedTransactedTokenNonErc20BlockNumberKey(wallet)) as? [String: NSNumber] else { return nil }
        return dictionary["\(server.chainID)"]?.intValue
    }

    public struct Keys {
        static let chainID = "chainID"
        static let isCryptoPrimaryCurrency = "isCryptoPrimaryCurrency"
        static let currency = "currencyID"
        static let dAppBrowser = "dAppBrowser"
        //There *is* a trailing space in the key
        static let walletAddressesAlreadyPromptedForBackUp = "walletAddressesAlreadyPromptedForBackUp "
        static let locale = "locale"
        static let enabledServers = "enabledChains"
        static let lastFetchedErc20InteractionBlockNumber = "lastFetchedErc20InteractionBlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenErc20BlockNumber = "lastFetchedAutoDetectedTransactedTokenErc20BlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenErc721BlockNumber = "lastFetchedAutoDetectedTransactedTokenErc721BlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenErc1155BlockNumber = "lastFetchedAutoDetectedTransactedTokenErc1155BlockNumber"
        static let lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber = "lastFetchedAutoDetectedTransactedTokenNonErc20BlockNumber"
        static let walletNames = "walletNames"
        //We don't write to this key anymore as we support more than 1 service provider. Reading this key only for legacy reasons
        static let usePrivateNetwork = "usePrivateNetworkKey"
        static let privateNetworkProvider = "privateNetworkProvider"
        static let homePageURL = "homePageURL"
        static let sendAnalyticsEnabled = "sendAnalyticsEnabled"
        static let sendCrashReportingEnabled = "sendCrashReportingEnabled"
    }

    public let defaults: UserDefaults
    public var isSendAnalyticsEnabled: Bool {
        sendAnalyticsEnabled ?? false
    }

    public var sendAnalyticsEnabled: Bool? {
        get {
            guard Features.current.isAvailable(.isAnalyticsUIEnabled) else { return nil }
            guard let value = defaults.value(forKey: Keys.sendAnalyticsEnabled) as? Bool else {
                return nil
            }

            return value
        }
        set {
            guard Features.current.isAvailable(.isAnalyticsUIEnabled) else {
                defaults.removeObject(forKey: Keys.sendAnalyticsEnabled)
                return
            }

            defaults.set(newValue, forKey: Keys.sendAnalyticsEnabled)
        }
    }

    public var isSendCrashReportingEnabled: Bool {
        sendCrashReportingEnabled ?? false
    }

    public var sendCrashReportingEnabled: Bool? {
        get {
            guard let value = defaults.value(forKey: Keys.sendCrashReportingEnabled) as? Bool else {
                return nil
            }

            return value
        }
        set {
            defaults.set(newValue, forKey: Keys.sendCrashReportingEnabled)
        }
    }

    public var sendPrivateTransactionsProvider: SendPrivateTransactionsProvider? {
        get {
            guard Features.current.isAvailable(.isUsingPrivateNetwork) else { return nil }
            if defaults.bool(forKey: Keys.usePrivateNetwork) {
                //Default, for legacy reasons
                return .ethermine
            } else {
                let s = defaults.string(forKey: Keys.privateNetworkProvider)
                return s.flatMap { SendPrivateTransactionsProvider(rawValue: $0) }
            }
        }
        set {
            guard Features.current.isAvailable(.isUsingPrivateNetwork) else { return }
            defaults.set(newValue?.rawValue, forKey: Keys.privateNetworkProvider)
        }
    }

    public var enabledServers: [RPCServer] {
        get {
            if let chainIds = defaults.array(forKey: Keys.enabledServers) as? [Int] {
                if chainIds.isEmpty {
                    //TODO remote log. Why is this possible? Note it's not nil (which is possible for new installs)
                    return Constants.defaultEnabledServers
                } else {
                    //Remove duplicates. Useful for the occasion where users have enabled a chain, then we disable that chain in an update and the user might now end up with the Ethereum mainnet twice (default when we can't find a chain that we removed) in their enabled list
                    let servers: [RPCServer] = Array(Set(chainIds.map { .init(chainID: $0) }.filter { $0.conflictedServer == nil }))
                    return servers
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

    public var homePageURL: URL? {
        get {
            return defaults.string(forKey: Keys.homePageURL).flatMap { URL(string: $0) }
        }
        set {
            defaults.set(newValue?.absoluteString, forKey: Keys.homePageURL)
        }
    }

    public var enabledServersPublisher: AnyPublisher<[RPCServer], Never> {
        Self.enabledServersSubject
            .filter { !$0.isEmpty }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    //NOTE: keep static while not reduce amount of created instances of `Config`, need to reduce up it to using single instance of Config
    private static var enabledServersSubject: CurrentValueSubject<[RPCServer], Never> = .init([])

    public init(defaults: UserDefaults = UserDefaults.standardOrForTests) {
        self.defaults = defaults
    }

    public var oldWalletAddressesAlreadyPromptedForBackUp: [String] {
        //We hard code the key here because it's used for migrating off the old value, there should be no reason why this key will change in the next line
        //There *is* a trailing space in the key
        if let addresses = defaults.array(forKey: "walletAddressesAlreadyPromptedForBackUp ") {
            return addresses as! [String]
        } else {
            return []
        }
    }

    public func addToWalletAddressesAlreadyPromptedForBackup(address: AlphaWallet.Address) {
        var addresses: [String]
        if let value = defaults.array(forKey: Keys.walletAddressesAlreadyPromptedForBackUp) {
            addresses = value as! [String]
        } else {
            addresses = [String]()
        }
        addresses.append(address.eip55String)
        defaults.setValue(addresses, forKey: Keys.walletAddressesAlreadyPromptedForBackUp)
    }

    public func anyEnabledServer() -> RPCServer {
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
