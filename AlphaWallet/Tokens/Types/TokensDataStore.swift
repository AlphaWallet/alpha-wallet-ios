// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import Result
import RealmSwift
import SwiftyJSON

enum TokenError: Error {
    case failedToFetch
}

protocol TokensDataStoreDelegate: AnyObject {
    func didUpdate(in tokensDataStore: TokensDataStore, refreshImmediately: Bool)
}

// swiftlint:disable type_body_length
class TokensDataStore {
    static let fetchContractDataTimeout = TimeInterval(4)
    private let realm: Realm
    private var chainId: Int {
        return server.chainID
    }
    private let config: Config
    private let queue = DispatchQueue.main

    let account: Wallet
    let server: RPCServer

    weak var delegate: TokensDataStoreDelegate?
    var tokensModel: Subscribable<[TokenObject]> = Subscribable(nil)

    private var enabledObjectResults: Results<TokenObject> {
        realm.objects(TokenObject.self)
            .filter("chainId = \(self.chainId)")
            .filter("contract != ''")
            .filter("isDisabled = false")
    }

    var objects: [TokenObject] {
        return Array(
                realm.objects(TokenObject.self)
                        .filter("chainId = \(self.chainId)")
                        .filter("contract != ''")
        )
    }

    //TODO might be good to change `enabledObject` to just return the streaming list from Realm instead of a Swift native Array and other properties/callers can convert to Array if necessary
    var enabledObject: [TokenObject] {
        let result = Array(realm.threadSafe.objects(TokenObject.self)
                .filter("chainId = \(self.chainId)")
                .filter("isDisabled = false"))
        if let erc20AddressForNativeToken = server.erc20AddressForNativeToken, result.contains(where: { $0.contractAddress.sameContract(as: erc20AddressForNativeToken) }) {
            return result.filter { !$0.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) }
        } else {
            return result
        }
    }

    var deletedContracts: [DeletedContract] {
        return Array(realm.threadSafe.objects(DeletedContract.self)
                .filter("chainId = \(self.chainId)"))
    }

    var delegateContracts: [DelegateContract] {
        return Array(realm.threadSafe.objects(DelegateContract.self)
                .filter("chainId = \(self.chainId)"))
    }

    var hiddenContracts: [HiddenContract] {
        return Array(realm.threadSafe.objects(HiddenContract.self)
                .filter("chainId = \(self.chainId)"))
    }

    static func etherToken(forServer server: RPCServer) -> TokenObject {
        return TokenObject(
                contract: Constants.nativeCryptoAddressInDatabase,
                server: server,
                name: server.name,
                symbol: server.symbol,
                decimals: server.decimals,
                value: "0",
                isCustom: false,
                type: .nativeCryptocurrency
        )
    }

    //TODO might be best to remove ethToken(for:) and just use token(for:) if possible, but careful with the contract value returned for .ether
    static func token(forServer server: RPCServer) -> TokenObject {
        return TokenObject(
                contract: server.priceID,
                server: server,
                name: server.name,
                symbol: server.symbol,
                decimals: server.decimals,
                value: "0",
                isCustom: false,
                type: .nativeCryptocurrency
        )
    }
    private var enabledObjectsSubscription: NotificationToken?

    init(
            realm: Realm,
            account: Wallet,
            server: RPCServer,
            config: Config
    ) {
        self.account = account
        self.server = server
        self.config = config
        self.realm = realm
        self.addEthToken()

        //TODO not needed for setupCallForAssetAttributeCoordinators? Look for other callers of DataStore.updateDelegate
        enabledObjectsSubscription = enabledObjectResults.observe(on: queue) { [weak self] change in
            switch change {
            case .initial:
                break
            case .update, .error:
                self?.updateDelegate(refreshImmediately: false)
            }
        }
    }

    private func addEthToken() {
        //Check if we have previous values.
        let etherToken = TokensDataStore.etherToken(forServer: server)
        if objects.first(where: { $0 == etherToken }) == nil {
            add(tokens: [etherToken])
        }
    }

    static func update(in realm: Realm, tokens: [TokenUpdate]) {
        realm.beginWrite()
        for token in tokens {
            //Even though primaryKey is provided, it is important to specific contract because this might be creating a new TokenObject instance from transactions
            let update: [String: Any] = [
                "primaryKey": token.primaryKey,
                "contract": token.address.eip55String,
                "chainId": token.server.chainID,
                "name": token.name,
                "symbol": token.symbol,
                "decimals": token.decimals,
                "rawType": token.tokenType.rawValue,
            ]
            realm.create(TokenObject.self, value: update, update: .all)
        }
        try! realm.commitWrite()
    }

    func fetch() {
        refreshBalance()
    }

    func tokenThreadSafe(forContract contract: AlphaWallet.Address) -> TokenObject? {
        realm.threadSafe.objects(TokenObject.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("chainId = \(chainId)").first
    }

    func token(forContract contract: AlphaWallet.Address) -> TokenObject? {
        realm.objects(TokenObject.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("chainId = \(chainId)").first
    }

    private func refreshBalance() {
        //TODO updateDelegate() is needed so the data (eg. tokens in Wallet tab when app launches) can appear immediately (by reading from the database) while updated data is downloaded. Though it probably doesn't need to be called an additional time, every time. It is important to refresh immediately first, rather than be rate limited because we might be deleting (hiding) a token and the user should see the list of tokens refresh immediately
        updateDelegate(refreshImmediately: true)
    }

    private func updateDelegate(refreshImmediately: Bool = false) {
        tokensModel.value = enabledObject

        delegate?.didUpdate(in: self, refreshImmediately: refreshImmediately)
    }

    @discardableResult func addCustom(token: ERCToken) -> TokenObject {
        let newToken = TokenObject(
                contract: token.contract,
                server: token.server,
                name: token.name,
                symbol: token.symbol,
                decimals: token.decimals,
                value: "0",
                isCustom: true,
                type: token.type
        )
        token.balance.forEach { balance in
            newToken.balance.append(TokenBalance(balance: balance))
        }
        add(tokens: [newToken])

        return newToken
    }

    func add(deadContracts: [DeletedContract]) {
        try! realm.write {
            realm.add(deadContracts, update: .all)
        }
    }

    func add(delegateContracts: [DelegateContract]) {
        try! realm.write {
            realm.add(delegateContracts, update: .all)
        }
    }

    func add(hiddenContracts: [HiddenContract]) {
        try! realm.write {
            realm.add(hiddenContracts, update: .all)
        }
    }

    @discardableResult
    func add(tokens: [TokenObject]) -> [TokenObject] {
        realm.beginWrite()

        //TODO: save existed sort index and displaying state
        for token in tokens {
            if let object = self.realm.object(ofType: TokenObject.self, forPrimaryKey: token.primaryKey) {
                token.sortIndex = object.sortIndex
                token.shouldDisplay = object.shouldDisplay
            }
            realm.add(token, update: .all)
        }

        try! realm.commitWrite()
        return tokens
    }

    func delete(tokens: [TokenObject]) {
        realm.beginWrite()
        realm.delete(tokens)
        try! realm.commitWrite()
    }

    func delete(hiddenContracts: [HiddenContract]) {
        realm.beginWrite()
        realm.delete(hiddenContracts)
        try! realm.commitWrite()
    }

    enum TokenUpdateAction {
        case value(BigInt)
        case isDisabled(Bool)
        case nonFungibleBalance([String])
        case name(String)
        case type(TokenType)
        case isHidden(Bool)
    }

    func updateOrderedTokens(with orderedTokens: [TokenObject]) {
        let orderedTokensIds = orderedTokens.map {
            $0.primaryKey
        }

        let storedTokens = realm.objects(TokenObject.self)

        for token in storedTokens {
            try! realm.write {
                token.sortIndex.value = orderedTokensIds.firstIndex(where: { $0 == token.primaryKey })
            }
        }
    }

    func update(token: TokenObject, action: TokenUpdateAction) {
        guard !token.isInvalidated else { return }
        switch action {
        case .isHidden(let value):
            try! realm.write {
                token.shouldDisplay = !value
                if !value {
                    token.sortIndex.value = nil
                }
            }
        case .value(let value):
            try! realm.write {
                token.value = value.description
            }
        case .isDisabled(let value):
            try! realm.write {
                token.isDisabled = value
            }
        case .nonFungibleBalance(let balance):
            //Performance: if we use realm.write {} directly, the UI will block for a few seconds because we are reading from Realm, appending to an array and writing back to Realm many times (once for each token) in the main thread. Instead, we do this for each token in a background thread
            let primaryKey = token.primaryKey
            queue.async {
                let realmInBackground = try! Realm(configuration: self.realm.configuration)
                let token = realmInBackground.object(ofType: TokenObject.self, forPrimaryKey: primaryKey)!
                var newBalance = [TokenBalance]()
                if !balance.isEmpty {
                    for i in 0...balance.count - 1 {
                        if let oldBalance = token.balance.first(where: { $0.balance == balance[i] }) {
                            newBalance.append(TokenBalance(balance: balance[i], json: oldBalance.json))
                        } else {
                            newBalance.append(TokenBalance(balance: balance[i]))
                        }
                    }
                }
                try! realmInBackground.write {
                    realmInBackground.delete(token.balance)
                    token.balance.append(objectsIn: newBalance)
                }
            }
        case .name(let name):
            try! realm.write {
                token.name = name
            }
        case .type(let type):
            try! realm.write {
                token.type = type
            }
        }
    }

    deinit {
        //We should make sure that timer is invalidate.
        enabledObjectsSubscription.flatMap { $0.invalidate() }
    }
}
// swiftlint:enable type_body_length

extension Realm {
    var threadSafe: Realm {
         try! Realm(configuration: self.configuration)
    }
}

extension TokenObject {
    var addressAndRPCServer: AddressAndRPCServer {
        return .init(address: contractAddress, server: server)
    }
}
