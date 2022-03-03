// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import RealmSwift
import Combine

enum TokenError: Error {
    case failedToFetch
}

///Multiple-chains tokens data store
protocol TokensDataStore: NSObjectProtocol {
    var account: Wallet { get }

    func enabledTokenObjectsChangesetPublisher(forServers servers: [RPCServer]) -> AnyPublisher<ChangeSet<[TokenObject]>, Never>
    func enabledTokenObjects(forServers servers: [RPCServer]) -> [TokenObject]

    func deletedContracts(forServer server: RPCServer) -> [DeletedContract]
    func delegateContracts(forServer server: RPCServer) -> [DelegateContract]
    func hiddenContracts(forServer server: RPCServer) -> [HiddenContract]
    func addEthToken(forServer server: RPCServer)
    func tokenObjectPromise(forContract contract: AlphaWallet.Address) -> Promise<TokenObject?>
    func tokenObjectPromise(forContract contract: AlphaWallet.Address, server: RPCServer) -> Promise<TokenObject?>
    func token(forContract contract: AlphaWallet.Address, server: RPCServer) -> TokenObject?
    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [TokenObject]
    func add(hiddenContracts: [HiddenContract])
    @discardableResult func add(tokens: [TokenObject]) -> [TokenObject]
    func delete(tokens: [TokenObject])
    func delete(hiddenContracts: [HiddenContract])
    func updateOrderedTokens(with orderedTokens: [TokenObject])

    @discardableResult func updateToken(primaryKey: String, action: TokenUpdateAction) -> Bool?
    @discardableResult func addTokenObjects(values: [SingleChainTokensAutodetector.AddTokenObjectOperation]) -> [TokenObject]
    @discardableResult func batchUpdateTokenPromise(_ actions: [PrivateBalanceFetcher.TokenBatchOperation]) -> Bool?
}

enum TokenUpdateAction {
    case value(BigInt)
    case isDisabled(Bool)
    case nonFungibleBalance([String])
    case name(String)
    case type(TokenType)
    case isHidden(Bool)
}

// Should be `final`, but removed for test purposes
/*final*/ class MultipleChainsTokensDataStore: NSObject, TokensDataStore {
    private let realm: Realm
    let account: Wallet

    init(realm: Realm, account: Wallet, servers: [RPCServer]) {
        self.account = account
        self.realm = realm

        super.init()

        for each in servers {
            addEthToken(forServer: each)
        }
    }

    func enabledTokenObjectsChangesetPublisher(forServers servers: [RPCServer]) -> AnyPublisher<ChangeSet<[TokenObject]>, Never> {
        return enabledObjectResults(forServers: servers)
            .changesetPublisher
            .map { change in
                switch change {
                case .initial(let tokenObjects):
                    return .initial(Array(tokenObjects))
                case .update(let tokenObjects, let deletions, let insertions, let modifications):
                    return .update(Array(tokenObjects), deletions: deletions, insertions: insertions, modifications: modifications)
                case .error(let error):
                    return .error(error)
                }
            }
            .share()
            .eraseToAnyPublisher()
    }

    func enabledTokenObjects(forServers servers: [RPCServer]) -> [TokenObject] {
        let tokenObjects = Array(enabledObjectResults(forServers: servers).map { $0 })
        return MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: servers, tokenObjects: tokenObjects)
    }

    func deletedContracts(forServer server: RPCServer) -> [DeletedContract] {
        return Array(realm.objects(DeletedContract.self)
            .filter("chainId = \(server.chainID)"))
    }

    func delegateContracts(forServer server: RPCServer) -> [DelegateContract] {
        return Array(realm.objects(DelegateContract.self)
            .filter("chainId = \(server.chainID)"))
    }

    func hiddenContracts(forServer server: RPCServer) -> [HiddenContract] {
        return Array(realm.objects(HiddenContract.self)
            .filter("chainId = \(server.chainID)"))
    }

    func addEthToken(forServer server: RPCServer) {
        //Check if we have previous values.
        let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        let tokenObjects = realm.objects(TokenObject.self)
            .filter(MultipleChainsTokensDataStore.functional.nonEmptyContractTokenPredicate(server: server))

        if !tokenObjects.contains(where: { $0 == etherToken }) {
            add(tokens: [etherToken])
        } 
    }

    func tokenObjectPromise(forContract contract: AlphaWallet.Address) -> Promise<TokenObject?> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let predicate = MultipleChainsTokensDataStore
                    .functional
                    .tokenPredicate(contract: contract)
                let token = strongSelf.realm.objects(TokenObject.self)
                    .filter(predicate)
                    .first

                seal.fulfill(token)
            }
        }
    }

    func tokenObjectPromise(forContract contract: AlphaWallet.Address, server: RPCServer) -> Promise<TokenObject?> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let predicate = MultipleChainsTokensDataStore
                    .functional
                    .tokenPredicate(server: server, contract: contract)
                let token = strongSelf.realm.objects(TokenObject.self)
                    .filter(predicate)
                    .first

                seal.fulfill(token)
            }
        }
    }

    func token(forContract contract: AlphaWallet.Address, server: RPCServer) -> TokenObject? {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(server: server, contract: contract)

        return realm.objects(TokenObject.self)
            .filter(predicate)
            .first
    }

    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [TokenObject] {
        let newTokens = tokens.compactMap { MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: $0, shouldUpdateBalance: shouldUpdateBalance) }
        add(tokens: newTokens)

        return newTokens
    }

    @discardableResult func addTokenObjects(values: [SingleChainTokensAutodetector.AddTokenObjectOperation]) -> [TokenObject] {
        guard !values.isEmpty else { return [] }
        var tokenObjects: [TokenObject] = []

        try! realm.write {
            for each in values {
                switch each {
                case .delegateContracts(let delegateContract):
                    realm.add(delegateContract, update: .all)
                case .ercToken(let token):
                    let newToken = MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: token, shouldUpdateBalance: token.type.shouldUpdateBalanceWhenDetected)
                    addTokenUnsafe(tokenObject: newToken, realm: realm)
                    tokenObjects += [newToken]
                case .tokenObject(let tokenObject):
                    addTokenUnsafe(tokenObject: tokenObject, realm: realm)
                    tokenObjects += [tokenObject]
                case .deletedContracts(let deadContracts):
                    realm.add(deadContracts, update: .all)
                case .fungibleTokenComplete(let name, let symbol, let decimals, let contract, let server, let onlyIfThereIsABalance):
                    let existedTokenObject = token(forContract: contract, server: server)

                    let value = existedTokenObject?.value ?? "0"
                    guard !onlyIfThereIsABalance || (onlyIfThereIsABalance && !(value != "0")) else {
                        continue
                    }
                    let tokenObject = TokenObject(
                            contract: contract,
                            server: server,
                            name: name,
                            symbol: symbol,
                            decimals: Int(decimals),
                            value: value,
                            type: .erc20
                    )
                    addTokenUnsafe(tokenObject: tokenObject, realm: realm)
                    tokenObjects += [tokenObject]
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

    @discardableResult func batchUpdateTokenPromise(_ actions: [PrivateBalanceFetcher.TokenBatchOperation]) -> Bool? {
        realm.beginWrite()
        var result: Bool?

        for each in actions {
            var value: Bool?
            switch each {
            case .add(let token, let shouldUpdateBalance):
                let newToken = MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: token, shouldUpdateBalance: shouldUpdateBalance)
                addTokenUnsafe(tokenObject: newToken, realm: realm)
                value = true
            case .update(let tokenObject, let action):
                value = updateTokenUnsafe(primaryKey: tokenObject.primaryKey, action: action)
            }

            if result == nil {
                result = value
            }
        }

        try! realm.commitWrite()

        return result
    }

    @discardableResult func updateToken(primaryKey: String, action: TokenUpdateAction) -> Bool? {
        var result: Bool?
        realm.beginWrite()
        result = updateTokenUnsafe(primaryKey: primaryKey, action: action)

        try! realm.commitWrite()

        return result
    }

    //TODO: Group private and internal functions, mark private everithing
    @discardableResult private func addTokenUnsafe(tokenObject: TokenObject, realm: Realm) -> TokenObject {
        //TODO: save existed sort index and displaying state
        if let object = realm.object(ofType: TokenObject.self, forPrimaryKey: tokenObject.primaryKey) {
            tokenObject.sortIndex = object.sortIndex
            tokenObject.shouldDisplay = object.shouldDisplay
        }

        realm.add(tokenObject, update: .all)

        return tokenObject
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

    private func enabledObjectResults(forServers servers: [RPCServer]) -> Results<TokenObject> {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .nonEmptyContractTokenPredicateWithErc20AddressForNativeTokenFilter(servers: servers, isDisabled: false)

        return realm.objects(TokenObject.self)
            .filter(predicate)
    }
}

extension TokenObject {
    var addressAndRPCServer: AddressAndRPCServer {
        return .init(address: contractAddress, server: server)
    }
}

extension MultipleChainsTokensDataStore {
    class functional {}
}

extension MultipleChainsTokensDataStore.functional {
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

    static func chainIdPredicate(servers: [RPCServer]) -> NSPredicate {
        return NSPredicate(format: "chainId IN %@", servers.map { $0.chainID })
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
            chainIdPredicate(servers: [server])
        ])
    }

    static func tokenPredicate(server: RPCServer, contract: AlphaWallet.Address) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            contractPredicate(contract: contract),
            chainIdPredicate(servers: [server])
        ])
    }

    static func tokenPredicate(contract: AlphaWallet.Address) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            contractPredicate(contract: contract)
        ])
    }

    static func nonEmptyContractTokenPredicate(servers: [RPCServer], isDisabled: Bool) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            isDisabledPredicate(isDisabled: isDisabled),
            chainIdPredicate(servers: servers),
            nonEmptyContractPredicate()
        ])
    }

    static func nonEmptyContractTokenPredicateWithErc20AddressForNativeTokenFilter(servers: [RPCServer], isDisabled: Bool) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            isDisabledPredicate(isDisabled: isDisabled),
            chainIdPredicate(servers: servers),
            nonEmptyContractPredicate()
        ])
    }

    static func nonEmptyContractTokenPredicate(server: RPCServer) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate(servers: [server]),
            nonEmptyContractPredicate()
        ])
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

    //TODO: Rename tokenObject(ercToken with createTokenObject(ercToken, more clear name
    static func createTokenObject(ercToken token: ERCToken, shouldUpdateBalance: Bool) -> TokenObject {
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

    static func erc20AddressForNativeTokenFilter(servers: [RPCServer], tokenObjects: [TokenObject]) -> [TokenObject] {
        var result = tokenObjects
        for server in servers {
            if let address = server.erc20AddressForNativeToken, result.contains(where: { $0.contractAddress.sameContract(as: address) }) {
                result = result.filter { !$0.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) && $0.server == server }
            } else {
                continue
            }
        }

        return result
    }
}
