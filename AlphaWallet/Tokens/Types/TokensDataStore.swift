// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import RealmSwift

enum TokenError: Error {
    case failedToFetch
}

protocol TokensDataStoreDelegate: AnyObject {
    func didUpdate(in tokensDataStore: TokensDataStore, refreshImmediately: Bool)
}

class TokensDataStore: NSObject {
    static let fetchContractDataTimeout = TimeInterval(4)

    private let realm: Realm
    private var chainId: Int {
        return server.chainID
    }
    let account: Wallet
    let server: RPCServer

    weak var delegate: TokensDataStoreDelegate?

    var enabledObjectResults: Results<TokenObject> {
        return realm.objects(TokenObject.self)
            .filter(TokensDataStore.functional.nonEmptyContractTokenPredicate(server: server, isDisabled: false))
    }

    var enabledObjectAddresses: [AlphaWallet.Address] {
        enabledObjectResults
            .map { $0.contractAddress }
    }

    private var objects: [TokenObject] {
        return Array(realm.objects(TokenObject.self)
                        .filter(TokensDataStore.functional.nonEmptyContractTokenPredicate(server: server)))
    }

    //TODO might be good to change `enabledObject` to just return the streaming list from Realm instead of a Swift native Array and other properties/callers can convert to Array if necessary
    var enabledObject: [TokenObject] {
        let predicate = TokensDataStore
            .functional
            .nonEmptyContractTokenPredicate(server: server, isDisabled: false)

        let result = Array(realm.objects(TokenObject.self)
                            .filter(predicate))
        if let erc20AddressForNativeToken = server.erc20AddressForNativeToken, result.contains(where: { $0.contractAddress.sameContract(as: erc20AddressForNativeToken) }) {
            return result.filter { !$0.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) }
        } else {
            return result
        }
    }

    var tokenObjects: [Activity.AssignedToken] {
        let tokenObjects = enabledObject.map { Activity.AssignedToken(tokenObject: $0) }
        return Array(tokenObjects)
    }

    var deletedContracts: [DeletedContract] {
        return Array(realm.objects(DeletedContract.self)
            .filter("chainId = \(chainId)"))
    }

    var delegateContracts: [DelegateContract] {
        return Array(realm.objects(DelegateContract.self)
            .filter("chainId = \(chainId)"))
    }

    var hiddenContracts: [HiddenContract] {
        return Array(realm.objects(HiddenContract.self)
            .filter("chainId = \(chainId)"))
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

    init(realm: Realm, account: Wallet, server: RPCServer) {
        self.account = account
        self.server = server
        self.realm = realm

        super.init()

        self.addEthToken()

        //TODO not needed for setupCallForAssetAttributeCoordinators? Look for other callers of DataStore.updateDelegate
        enabledObjectsSubscription = enabledObjectResults.observe(on: .main) { [weak self] change in
            switch change {
            case .update:
                self?.updateDelegate(refreshImmediately: true)
            case .initial, .error:
                break
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

    func tokenPromise(forContract contract: AlphaWallet.Address) -> Promise<TokenObject?> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let predicate = TokensDataStore
                    .functional
                    .tokenPredicate(server: strongSelf.server, contract: contract)
                let token = strongSelf.realm.objects(TokenObject.self)
                    .filter(predicate)
                    .first

                seal.fulfill(token)
            }
        }
    }

    func token(forContract contract: AlphaWallet.Address) -> TokenObject? {
        let predicate = TokensDataStore
            .functional
            .tokenPredicate(server: server, contract: contract)

        return realm.objects(TokenObject.self)
            .filter(predicate)
            .first
    }

    private func updateDelegate(refreshImmediately: Bool = false) {
        //TODO updateDelegate() is needed so the data (eg. tokens in Wallet tab when app launches) can appear immediately (by reading from the database) while updated data is downloaded. Though it probably doesn't need to be called an additional time, every time. It is important to refresh immediately first, rather than be rate limited because we might be deleting (hiding) a token and the user should see the list of tokens refresh immediately
        delegate?.didUpdate(in: self, refreshImmediately: refreshImmediately)
    }

    @discardableResult func addCustom(token: ERCToken, shouldUpdateBalance: Bool) -> TokenObject {
        let newToken = TokensDataStore.tokenObject(ercToken: token, shouldUpdateBalance: shouldUpdateBalance)
        add(tokens: [newToken])

        return newToken
    }

    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [TokenObject] {
        let newTokens = tokens.compactMap { TokensDataStore.tokenObject(ercToken: $0, shouldUpdateBalance: shouldUpdateBalance) }
        add(tokens: newTokens)

        return newTokens
    }

    @discardableResult func addCustom(token: ERCToken) -> TokenObject {
        let newToken = TokensDataStore.tokenObject(ercToken: token, shouldUpdateBalance: true)

        add(tokens: [newToken])

        return newToken
    }

    private static func tokenObject(ercToken token: ERCToken, shouldUpdateBalance: Bool) -> TokenObject {
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
        if shouldUpdateBalance {
            token.balance.forEach { balance in
                newToken.balance.append(TokenBalance(balance: balance))
            }
        }

        return newToken
    }

    @discardableResult private func addTokenUnsafe(tokenObject: TokenObject, realm: Realm) -> TokenObject {
        //TODO: save existed sort index and displaying state
        if let object = realm.object(ofType: TokenObject.self, forPrimaryKey: tokenObject.primaryKey) {
            tokenObject.sortIndex = object.sortIndex
            tokenObject.shouldDisplay = object.shouldDisplay
        }

        realm.add(tokenObject, update: .all)

        return tokenObject
    }

    @discardableResult func addBatchObjects(values: [SingleChainTokenCoordinator.BatchObject]) -> [TokenObject] {
        guard !values.isEmpty else { return [] }
        var tokenObjects: [TokenObject] = []

        try! realm.write {
            for each in values {
                switch each {
                case .delegateContracts(let delegateContract):
                    realm.add(delegateContract, update: .all)
                case .ercToken(let token):
                    let newToken = Self.tokenObject(ercToken: token, shouldUpdateBalance: token.type.shouldUpdateBalanceWhenDetected)
                    addTokenUnsafe(tokenObject: newToken, realm: realm)
                    tokenObjects += [newToken]
                case .tokenObject(let tokenObject):
                    addTokenUnsafe(tokenObject: tokenObject, realm: realm)
                    tokenObjects += [tokenObject]
                case .deletedContracts(let deadContracts):
                    realm.add(deadContracts, update: .all)
                case .none:
                    break
                }
            }
        }

        return tokenObjects
    }

    func add(hiddenContracts: [HiddenContract]) {
        try! realm.write {
            realm.add(hiddenContracts, update: .all)
        }
    }

    @discardableResult func add(tokens: [TokenObject]) -> [TokenObject] {
        guard !tokens.isEmpty else { return [] }
        realm.beginWrite()

        //TODO: save existed sort index and displaying state
        for token in tokens {
            addTokenUnsafe(tokenObject: token, realm: realm)
        }

        try! realm.commitWrite()

        return tokens
    }

    func delete(tokens: [TokenObject]) {
        guard !tokens.isEmpty else { return }

        realm.beginWrite()
        realm.delete(tokens)
        try! realm.commitWrite()
    }

    func delete(hiddenContracts: [HiddenContract]) {
        guard !hiddenContracts.isEmpty else { return }

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
        guard !orderedTokens.isEmpty else { return }
        let orderedTokensIds = orderedTokens.map { $0.primaryKey }

        let storedTokens = realm.objects(TokenObject.self)

        for token in storedTokens {
            try! realm.write {
                token.sortIndex.value = orderedTokensIds.firstIndex(where: { $0 == token.primaryKey })
            }
        }
    }

    func update(token: TokenObject, action: TokenUpdateAction) {
        guard !token.isInvalidated else { return }
        try! realm.write {
            updateTokenUnsafe(primaryKey: token.primaryKey, action: action)
        }
    }

    deinit {
        //We should make sure that timer is invalidate.
        enabledObjectsSubscription.flatMap { $0.invalidate() }
    }

    func batchUpdateTokenPromise(_ actions: [PrivateBalanceFetcher.TokenBatchOperation]) -> Promise<Bool?> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                strongSelf.realm.beginWrite()
                var result: Bool?

                for each in actions {
                    var value: Bool?
                    switch each {
                    case .add(let token, let shouldUpdateBalance):
                        let newToken = TokensDataStore.tokenObject(ercToken: token, shouldUpdateBalance: shouldUpdateBalance)
                        strongSelf.addTokenUnsafe(tokenObject: newToken, realm: strongSelf.realm)
                        value = true
                    case .update(let tokenObject, let action):
                        value = strongSelf.updateTokenUnsafe(primaryKey: tokenObject.primaryKey, action: action)
                    }

                    if result == nil {
                        result = value
                    }
                }

                try! strongSelf.realm.commitWrite()

                seal.fulfill(result)
            }
        }
    }

    func updateTokenPromise(primaryKey: String, action: TokenUpdateAction) -> Promise<Bool?> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                let result = strongSelf.updateToken(primaryKey: primaryKey, action: action)

                seal.fulfill(result)
            }
        }
    }

    @discardableResult func updateToken(primaryKey: String, action: TokenUpdateAction) -> Bool? {
        var result: Bool?
        realm.beginWrite()
        result = updateTokenUnsafe(primaryKey: primaryKey, action: action)

        try! realm.commitWrite()

        return result
    }

    @discardableResult private func updateTokenUnsafe(primaryKey: String, action: TokenUpdateAction) -> Bool? {
        guard let tokenObject = realm.object(ofType: TokenObject.self, forPrimaryKey: primaryKey) else {
            return nil
        }

        var result: Bool = false

        switch action {
        case .value(let value):
            if tokenObject.value != value.description {
                tokenObject.value = value.description

                result = true
            }
        case .nonFungibleBalance(let balance):
            var newBalance = [TokenBalance]()
            if !balance.isEmpty {
                for i in 0...balance.count - 1 {
                    if let oldBalance = tokenObject.balance.first(where: { $0.balance == balance[i] }) {
                        newBalance.append(TokenBalance(balance: balance[i], json: oldBalance.json))
                    } else {
                        newBalance.append(TokenBalance(balance: balance[i]))
                    }
                }
            }

            result = true

            realm.delete(tokenObject.balance)
            tokenObject.balance.append(objectsIn: newBalance)

            //NOTE: for now we mark balance as hasn't changed for nonFungibleBalance, How to check that balance has update?
            result = true
        case .name(let name):
            if tokenObject.name != name {
                tokenObject.name = name
                result = true
            }
        case .type(let type):
            if tokenObject.rawType != type.rawValue {
                tokenObject.rawType = type.rawValue
                result = true
            }
        case .isDisabled(let value):
            result = true

            tokenObject.isDisabled = value
        case .isHidden(let value):
            result = true

            tokenObject.shouldDisplay = !value
            if !value {
                tokenObject.sortIndex.value = nil
            }
        }

        return result
    }
}

extension TokenObject {
    var addressAndRPCServer: AddressAndRPCServer {
        return .init(address: contractAddress, server: server)
    }
}

extension TokensDataStore {
    class functional {}
}

extension TokensDataStore.functional {
    static func nonFungibleTokenType(fromTokenType tokenType: TokenType) -> NonFungibleFromJsonTokenType {
        switch tokenType {
        case .erc721, .erc721ForTickets:
            return NonFungibleFromJsonTokenType.erc721
        case .erc1155:
            return NonFungibleFromJsonTokenType.erc1155
        case .nativeCryptocurrency, .erc20, .erc875:
            return NonFungibleFromJsonTokenType.erc721
        }
    }

    static func chainIdPredicate(server: RPCServer) -> NSPredicate {
        return NSPredicate(format: "chainId = \(server.chainID)")
    }

    static func isDisabledPredicate(isDisabled: Bool) -> NSPredicate {
        return NSPredicate(format: "isDisabled = \(isDisabled ? "true" : "false")")
    }

    static func nonEmptyContractPredicate() -> NSPredicate {
        return NSPredicate(format: "contract != ''")
    }

    static func contractPredicate(contract: AlphaWallet.Address) -> NSPredicate {
        return NSPredicate(format: "contract = '\(contract.eip55String)'")
    }

    static func tokenPredicate(server: RPCServer, isDisabled: Bool, contract: AlphaWallet.Address) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            contractPredicate(contract: contract),
            isDisabledPredicate(isDisabled: isDisabled),
            chainIdPredicate(server: server)
        ])
    }

    static func tokenPredicate(server: RPCServer, contract: AlphaWallet.Address) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            contractPredicate(contract: contract),
            chainIdPredicate(server: server)
        ])
    }

    static func nonEmptyContractTokenPredicate(server: RPCServer, isDisabled: Bool) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            isDisabledPredicate(isDisabled: isDisabled),
            chainIdPredicate(server: server),
            nonEmptyContractPredicate()
        ])
    }

    static func nonEmptyContractTokenPredicate(server: RPCServer) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate(server: server),
            nonEmptyContractPredicate()
        ])
    }
}
