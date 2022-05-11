// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletOpenSea
import BigInt
import RealmSwift
import Combine

enum DataStoreError: Error {
    case objectTypeMismatch
    case objectNotFound
    case objectDeleted
    case general(error: Error)
}

struct TokenChange {
    let token: TokenObject
    let change: TokenPropertiesChange
}

enum TokenPropertiesChange {
    case initial
    case changed(properties: [PropertyChange])
}

/// Multiple-chains tokens data store
protocol TokensDataStore: NSObjectProtocol {
    func enabledTokenObjectsChangesetPublisher(forServers servers: [RPCServer]) -> AnyPublisher<ChangeSet<[TokenObject]>, Never>
    func enabledTokenObjects(forServers servers: [RPCServer]) -> [TokenObject]
    func tokenValuePublisher(forContract contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<TokenObject?, DataStoreError>
    func deletedContracts(forServer server: RPCServer) -> [DeletedContract]
    func delegateContracts(forServer server: RPCServer) -> [DelegateContract]
    func hiddenContracts(forServer server: RPCServer) -> [HiddenContract]
    func addEthToken(forServer server: RPCServer)
    func token(forContract contract: AlphaWallet.Address) -> TokenObject?
    func token(forContract contract: AlphaWallet.Address, server: RPCServer) -> TokenObject?
    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [TokenObject]
    func add(hiddenContracts: [HiddenContract])
    func deleteTestsOnly(tokens: [TokenObject])
    func updateOrderedTokens(with orderedTokens: [TokenObject])
    func add(tokenUpdates updates: [TokenUpdate])
    @discardableResult func updateToken(primaryKey: String, action: TokenUpdateAction) -> Bool?
    @discardableResult func addTokenObjects(values: [SingleChainTokensAutodetector.AddTokenObjectOperation]) -> [TokenObject]
    @discardableResult func batchUpdateToken(_ actions: [PrivateBalanceFetcher.TokenBatchOperation]) -> Bool?
}

enum TokenUpdateAction {
    case value(BigInt)
    case isDisabled(Bool)
    case nonFungibleBalance([String])
    case name(String)
    case type(TokenType)
    case isHidden(Bool)
}

/// Should be `final`, but removed for test purposes
/*final*/ class MultipleChainsTokensDataStore: NSObject, TokensDataStore {
    //NOTE: adds synchronized access to realm, to make requests from different threads. Replace other calls
    private let store: RealmStore
    private let queue = DispatchQueue(label: "com.MultipleChainsTokensDataStore.UpdateQueue")

    init(store: RealmStore, servers: [RPCServer]) {
        self.store = store
        super.init()

        queue.async {
            for each in servers {
                self.addEthToken(forServer: each)
            }
        }
    }

    func enabledTokenObjectsChangesetPublisher(forServers servers: [RPCServer]) -> AnyPublisher<ChangeSet<[TokenObject]>, Never> {
        var publisher: AnyPublisher<ChangeSet<[TokenObject]>, Never>!
        store.performSync { realm in
            publisher = enabledTokenObjectResults(forServers: servers, realm: realm)
                .changesetPublisher
                .subscribe(on: queue)
                .map { change in
                    switch change {
                    case .initial(let tokenObjects):
                        return .initial(tokenObjects.toArray())
                    case .update(let tokenObjects, let deletions, let insertions, let modifications):
                        return .update(tokenObjects.toArray(), deletions: deletions, insertions: insertions, modifications: modifications)
                    case .error(let error):
                        return .error(error)
                    }
                }
                .eraseToAnyPublisher()
        }

        return publisher
    }

    func tokenValuePublisher(forContract contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<TokenObject?, DataStoreError> {
            let predicate = MultipleChainsTokensDataStore
                .functional
                .tokenPredicate(server: server, contract: contract)

            let publisher: CurrentValueSubject<TokenObject?, DataStoreError> = .init(nil)
            var cancelable: AnyCancellable?

            store.performSync { realm in
                guard let token = realm.objects(TokenObject.self).filter(predicate).first else {
                    publisher.send(completion: .failure(DataStoreError.objectNotFound))
                    return
                }
                let valuePublisher = token
                    .publisher(for: \.value, options: [.initial, .new])
                    .map { _ -> TokenObject in return token.detached() }
                    .receive(on: queue)
                    .setFailureType(to: DataStoreError.self)

                cancelable = valuePublisher
                    .sink(receiveCompletion: { compl in
                        publisher.send(completion: compl)
                    }, receiveValue: { token in
                        publisher.send(token)
                    })
            }

            return publisher
                .handleEvents(receiveCancel: {
                    cancelable?.cancel()
                })
                .eraseToAnyPublisher()
        }

    func enabledTokenObjects(forServers servers: [RPCServer]) -> [TokenObject] {
        var tokens: [TokenObject] = []
        store.performSync { realm in
            let _tokens = enabledTokenObjectResults(forServers: servers, realm: realm).toArray()
            tokens = MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: servers, tokenObjects: _tokens)
        }

        return tokens
    }

    func deletedContracts(forServer server: RPCServer) -> [DeletedContract] {
        var deletedContracts: [DeletedContract] = []
        store.performSync { realm in
            deletedContracts = Array(realm.objects(DeletedContract.self).filter("chainId = \(server.chainID)"))
        }

        return deletedContracts
    }

    func delegateContracts(forServer server: RPCServer) -> [DelegateContract] {
        var delegateContracts: [DelegateContract] = []
        store.performSync { realm in
            delegateContracts = Array(realm.objects(DelegateContract.self).filter("chainId = \(server.chainID)"))
        }
        return delegateContracts
    }

    func hiddenContracts(forServer server: RPCServer) -> [HiddenContract] {
        var hiddenContracts: [HiddenContract] = []
        store.performSync { realm in
            hiddenContracts = Array(realm.objects(HiddenContract.self).filter("chainId = \(server.chainID)"))
        }
        return hiddenContracts
    }

    func add(tokenUpdates updates: [TokenUpdate]) {
        store.performSync { realm in
            try? realm.safeWrite {
                for token in updates {
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
            }
        }
    }

    func addEthToken(forServer server: RPCServer) {
        var tokenObjects: [TokenObject] = []
        store.performSync { realm in
            tokenObjects = realm.objects(TokenObject.self)
                .filter(MultipleChainsTokensDataStore.functional.nonEmptyContractTokenPredicate(server: server))
                .map { $0.detached() }
        }

            //Check if we have previous values.
        let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        if !tokenObjects.contains(where: { $0 == etherToken }) {
            add(tokens: [etherToken])
        }
    }

    func token(forContract contract: AlphaWallet.Address) -> TokenObject? {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(contract: contract)

        var token: TokenObject?
        store.performSync { realm in
            token = realm.objects(TokenObject.self)
                .filter(predicate)
                .toArray()
                .first
        }

        return token
    }

    func token(forContract contract: AlphaWallet.Address, server: RPCServer) -> TokenObject? {
        var token: TokenObject?
        store.performSync { realm in
            token = self.token(forContract: contract, server: server, realm: realm)
        }

        return token
    }

    private func token(forContract contract: AlphaWallet.Address, server: RPCServer, realm: Realm) -> TokenObject? {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(server: server, contract: contract)

        return realm.objects(TokenObject.self)
            .filter(predicate)
            .toArray()
            .first
    }

    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [TokenObject] {
        let newTokens = tokens.compactMap { MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: $0, shouldUpdateBalance: shouldUpdateBalance) }
        add(tokens: newTokens)

        return newTokens
    }

    @discardableResult func addTokenObjects(values: [SingleChainTokensAutodetector.AddTokenObjectOperation]) -> [TokenObject] {
        guard !values.isEmpty else { return [] }

        store.performSync { realm in
            try? realm.safeWrite {
                for each in values {
                    switch each {
                    case .delegateContracts(let delegateContract):
                        realm.add(delegateContract, update: .all)
                    case .ercToken(let token):
                        let newToken = MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: token, shouldUpdateBalance: token.type.shouldUpdateBalanceWhenDetected)
                        addTokenWithoutCommitWrite(tokenObject: newToken, realm: realm)
                    case .tokenObject(let tokenObject):
                        addTokenWithoutCommitWrite(tokenObject: tokenObject, realm: realm)
                    case .deletedContracts(let deadContracts):
                        realm.add(deadContracts, update: .all)
                    case .fungibleTokenComplete(let name, let symbol, let decimals, let contract, let server, let onlyIfThereIsABalance):
                        let existedTokenObject = token(forContract: contract, server: server, realm: realm)

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
                        addTokenWithoutCommitWrite(tokenObject: tokenObject, realm: realm)
                    case .none:
                        break
                    }
                }
            }
        }

        let tokenObjects = values
            .compactMap { $0.addressAndRPCServer }
            .compactMap { token(forContract: $0.address, server: $0.server) }

        return tokenObjects
    }

    func add(hiddenContracts: [HiddenContract]) {
        store.performSync { realm in
            try? realm.safeWrite {
                realm.add(hiddenContracts, update: .all)
            }
        }
    }

    @discardableResult func add(tokens: [TokenObject]) -> [TokenObject] {
        guard !tokens.isEmpty else { return [] }
        var tokensToReturn: [TokenObject] = []
        store.performSync { realm in
            try? realm.safeWrite {
                //TODO: save existed sort index and displaying state
                for token in tokens {
                    tokensToReturn += [addTokenWithoutCommitWrite(tokenObject: token, realm: realm)]
                }
            }
        }

        return tokensToReturn
    }

    func deleteTestsOnly(tokens: [TokenObject]) {
        guard !tokens.isEmpty else { return }

        store.performSync { realm in
            try? realm.safeWrite {
                realm.delete(tokens)
            }
        }
    }

    func updateOrderedTokens(with orderedTokens: [TokenObject]) {
        guard !orderedTokens.isEmpty else { return }
        store.performSync { realm in
            let orderedTokensIds = orderedTokens.map { $0.primaryKey }

            let storedTokens = Array(realm.objects(TokenObject.self))
            guard !storedTokens.isEmpty else { return }

            try? realm.safeWrite {
                for token in storedTokens {
                    token.sortIndex.value = orderedTokensIds.firstIndex(where: { $0 == token.primaryKey })
                }
            }
        }
    }

    @discardableResult func batchUpdateToken(_ actions: [PrivateBalanceFetcher.TokenBatchOperation]) -> Bool? {
        guard !actions.isEmpty else { return nil }

        var result: Bool?
        store.performSync { realm in
            try? realm.safeWrite {
                for each in actions {
                    var value: Bool?
                    switch each {
                    case .add(let token, let shouldUpdateBalance):
                        let newToken = MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: token, shouldUpdateBalance: shouldUpdateBalance)
                        addTokenWithoutCommitWrite(tokenObject: newToken, realm: realm)
                        value = true
                    case .update(let tokenObject, let action):
                        value = updateTokenWithoutCommitWrite(primaryKey: tokenObject.primaryKey, action: action, realm: realm)
                    }

                    if result == nil {
                        result = value
                    }
                }
            }
        }
        return result
    }

    @discardableResult func updateToken(primaryKey: String, action: TokenUpdateAction) -> Bool? {
        var result: Bool?
        store.performSync { realm in
            try? realm.safeWrite {
                result = updateTokenWithoutCommitWrite(primaryKey: primaryKey, action: action, realm: realm)
            }
        }

        return result
    }

    //TODO: Group private and internal functions, mark private everithing
    @discardableResult private func addTokenWithoutCommitWrite(tokenObject: TokenObject, realm: Realm) -> TokenObject {
        //TODO: save existed sort index and displaying state
        if let object = realm.object(ofType: TokenObject.self, forPrimaryKey: tokenObject.primaryKey) {
            tokenObject.sortIndex = object.sortIndex
            tokenObject.shouldDisplay = object.shouldDisplay
        }

        realm.add(tokenObject, update: .all)

        return tokenObject
    }

    @discardableResult private func updateTokenWithoutCommitWrite(primaryKey: String, action: TokenUpdateAction, realm: Realm) -> Bool? {
        guard let tokenObject = realm.object(ofType: TokenObject.self, forPrimaryKey: primaryKey) else { return nil }

        var result: Bool = false

        switch action {
        case .value(let value):
            return updateFungibleBalance(balance: value, token: tokenObject)
        case .nonFungibleBalance(let balances):
            return updateNonFungibleBalance(balances: balances, token: tokenObject)
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

    private func updateFungibleBalance(balance value: BigInt, token: TokenObject) -> Bool {
        if token.value != value.description {
            token.value = value.description
            return true
        }

        return false
    }

    private func updateNonFungibleBalance(balances: [String], token: TokenObject) -> Bool {
        //NOTE: add new balances
        let balancesToAdd = balances
            .filter { b in !token.balance.contains(where: { v in v.balance == b }) }
            .map { TokenBalance(balance: $0) }

        //NOTE: remove old balances if something has changed
        let balancesToDelete = token.balance
            .filter { !balances.contains($0.balance) }
            .compactMap { token.balance.index(of: $0) }

        if !balancesToAdd.isEmpty || !balancesToDelete.isEmpty {
            token.balance.append(objectsIn: balancesToAdd)

            for index in balancesToDelete {
                token.balance.remove(at: index)
            }
            return true
        }

        return false
    }

    private func enabledTokenObjectResults(forServers servers: [RPCServer], realm: Realm) -> Results<TokenObject> {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .nonEmptyContractTokenPredicateWithErc20AddressForNativeTokenFilter(servers: servers, isDisabled: false)

        return realm
            .objects(TokenObject.self)
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
