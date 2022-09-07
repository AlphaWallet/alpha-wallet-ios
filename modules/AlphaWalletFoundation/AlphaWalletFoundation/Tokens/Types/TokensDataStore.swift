// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletOpenSea
import BigInt
import RealmSwift
import Combine

public enum DataStoreError: Error {
    case objectTypeMismatch
    case objectNotFound
    case objectDeleted
    case general(error: Error)
}

/// Multiple-chains tokens data store
public protocol TokensDataStore: NSObjectProtocol {
    func enabledTokensChangeset(for servers: [RPCServer]) -> AnyPublisher<ChangeSet<[Token]>, Never>
    func enabledTokens(for servers: [RPCServer]) -> [Token]
    func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, DataStoreError>
    func deletedContracts(forServer server: RPCServer) -> [AddressAndRPCServer]
    func delegateContracts(forServer server: RPCServer) -> [AddressAndRPCServer]
    func hiddenContracts(forServer server: RPCServer) -> [AddressAndRPCServer]
    func addEthToken(forServer server: RPCServer)
    func token(forContract contract: AlphaWallet.Address) -> Token?
    func token(forContract contract: AlphaWallet.Address, server: RPCServer) -> Token?
    func add(hiddenContracts: [AddressAndRPCServer])
    func deleteTestsOnly(tokens: [Token])
    func tokenBalancesTestsOnly() -> [TokenBalanceValue]
    func add(tokenUpdates updates: [TokenUpdate])
    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token]
    @discardableResult func updateToken(primaryKey: String, action: TokenUpdateAction) -> Bool?
    @discardableResult func addOrUpdate(tokensOrContracts: [TokenOrContract]) -> [Token]
    @discardableResult func addOrUpdate(_ actions: [AddOrUpdateTokenAction]) -> Bool?
}

extension TokensDataStore {
    
    @discardableResult func updateToken(addressAndRpcServer: AddressAndRPCServer, action: TokenUpdateAction) -> Bool? {
        let primaryKey = TokenObject.generatePrimaryKey(fromContract: addressAndRpcServer.address, server: addressAndRpcServer.server)
        return updateToken(primaryKey: primaryKey, action: action)
    }

    func initialOrNewTokensPublisher(for servers: [RPCServer]) -> AnyPublisher<[Token], Never> {
        return enabledTokensChangeset(for: servers)
            .tryMap { changeset -> [Token] in
                switch changeset {
                case .initial(let tokens): return tokens
                case .update(let tokens, _, let insertions, _): return insertions.map { tokens[$0] }
                case .error: return []
                }
            }.replaceError(with: [])
            .filter { !$0.isEmpty }
            .eraseToAnyPublisher()
    }

    func enabledTokensPublisher(for servers: [RPCServer]) -> AnyPublisher<[Token], Never> {
        return enabledTokensChangeset(for: servers)
            .map { changeset in
                  switch changeset {
                  case .initial(let tokens): return tokens
                  case .update(let tokens, _, _, _): return tokens
                  case .error: return []
                  }
            }.eraseToAnyPublisher()
    }
}

public enum TokenOrContract {
    case ercToken(ERCToken)
    case token(Token)
    case delegateContracts([AddressAndRPCServer])
    case deletedContracts([AddressAndRPCServer])
    /// We re-use the existing balance value to avoid the `Wallets` tab showing that token (if it already exist) as `balance = 0` momentarily
    case fungibleTokenComplete(name: String, symbol: String, decimals: UInt8, contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool)
    case none

    var addressAndRPCServer: AddressAndRPCServer? {
        switch self {
        case .ercToken(let eRCToken):
            return .init(address: eRCToken.contract, server: eRCToken.server)
        case .token(let token):
            return .init(address: token.contractAddress, server: token.server)
        case .delegateContracts, .deletedContracts, .none:
            return nil
        case .fungibleTokenComplete(_, _, _, let contract, let server, _):
            return .init(address: contract, server: server)
        }
    }
}

public enum AddOrUpdateTokenAction {
    case add(ERCToken, shouldUpdateBalance: Bool)
    case update(token: Token, action: TokenUpdateAction)
}

//TODO: Rename with more better name
public struct NonFungibleBalanceAndItsSource<T> {
    public let tokenId: String
    public let value: T
    public let source: NonFungibleBalance.Source
}

public typealias JsonString = String

public enum NonFungibleBalance {
    /// The value taken from `openSea, enjin, or Uri`
    case assets([NftAssetRawValue])
    /// The value taken from `getBalances` function call for `erc721ForTickets`
    case erc721ForTickets([String])
    /// The value taken from `balanceOf` function call for `erc875`
    case erc875([String])
    /// The value taken from `balanceOf` function call for `erc721`
    case balance([String])

    public var rawValue: [String] {
        switch self {
        case .assets(let values):
            return values.map { $0.json }
        case .erc875(let values):
            return values
        case .erc721ForTickets(let values):
            return values
        case .balance(let value):
            return value
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .assets(let values):
            return values.isEmpty
        case .erc875(let values):
            return values.isEmpty
        case .erc721ForTickets(let values):
            return values.isEmpty
        case .balance(let value):
            return value.isEmpty
        }
    }

    public struct NftAssetRawValue {
        public let json: JsonString
        public var source: Source = .undefined
        
        public init(json: JsonString, source: Source) {
            self.json = json
            self.source = source
        }
    }

    public enum Source: CustomStringConvertible {
        /// Generated with loading from Url
        case uri(URL)
        /// Generated with some on native providers, web3 call for erc20 token
        case nativeProvider(ProviderType)
        /// Generated with fallback function,
        case fallback
        /// Other case
        case undefined

        public var description: String {
            switch self {
            case .uri(let url):
                return url.absoluteString
            case .nativeProvider(let provider):
                return "\(provider.rawValue) Provider"
            case .fallback:
                return "Fallback"
            case .undefined:
                return "Undefined"
            }
        }
    }

    public enum ProviderType: String {
        case nativeCrypto
        case erc20
        case erc875
        case erc721ForTickets
        case openSea
    }
}

public enum TokenUpdateAction {
    case value(BigInt)
    case isDisabled(Bool)
    case nonFungibleBalance(NonFungibleBalance)
    case name(String)
    case type(TokenType)
    case isHidden(Bool)
    case imageUrl(URL?)
    case coinGeckoTickerId(String)
}

open class MultipleChainsTokensDataStore: NSObject, TokensDataStore {
    private let store: RealmStore

    public init(store: RealmStore, servers: [RPCServer]) {
        self.store = store
        super.init()

        for each in servers {
            addEthToken(forServer: each)
        }

        MultipleChainsTokensDataStore.functional.recreateMissingInfoTokenObjects(for: store)
    }

    public func enabledTokensChangeset(for servers: [RPCServer]) -> AnyPublisher<ChangeSet<[Token]>, Never> {
        var publisher: AnyPublisher<ChangeSet<[Token]>, Never>!
        store.performSync { realm in
            publisher = self.enabledTokenObjectResults(forServers: servers, realm: realm)
                .changesetPublisher
                .freeze()
                .receive(on: DispatchQueue.global())
                .map { change in
                    switch change {
                    case .initial(let tokenObjects):
                        let tokens = Array(tokenObjects).map { Token(tokenObject: $0) }
                        return .initial(tokens)
                    case .update(let tokenObjects, let deletions, let insertions, let modifications):
                        let tokens = Array(tokenObjects).map { Token(tokenObject: $0) }
                        return .update(tokens, deletions: deletions, insertions: insertions, modifications: modifications)
                    case .error(let error):
                        return .error(error)
                    }
                }.eraseToAnyPublisher()
        }

        return publisher
    }

    public func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, DataStoreError> {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(server: server, contract: contract)

        let publisher: CurrentValueSubject<Token?, DataStoreError> = .init(nil)
        var notificationToken: NotificationToken?

        store.performSync { realm in
            guard let tokenObject = realm.objects(TokenObject.self).filter(predicate).first else {
                publisher.send(completion: .failure(DataStoreError.objectNotFound))
                return
            }

            publisher.send(Token(tokenObject: tokenObject))

            notificationToken = tokenObject.observe { change in
                switch change {
                case .change(let object, _):
                    guard let token = object as? TokenObject else { return }
                    publisher.send(Token(tokenObject: token))
                case .deleted:
                    publisher.send(completion: .failure(.objectDeleted))
                case .error(let e):
                    publisher.send(completion: .failure(.general(error: e)))
                }
            }
        }

        return publisher
            .handleEvents(receiveCancel: {
                notificationToken?.invalidate()
            }).eraseToAnyPublisher()
    }

    public func enabledTokens(for servers: [RPCServer]) -> [Token] {
        var tokensToReturn: [Token] = []
        store.performSync { realm in
            let tokens = Array(self.enabledTokenObjectResults(forServers: servers, realm: realm).map { Token(tokenObject: $0) })
            tokensToReturn = MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: servers, tokens: tokens)
        }

        return tokensToReturn
    }

    public func deletedContracts(forServer server: RPCServer) -> [AddressAndRPCServer] {
        var deletedContracts: [AddressAndRPCServer] = []
        store.performSync { realm in
            deletedContracts = Array(realm.objects(DeletedContract.self).filter("chainId = \(server.chainID)"))
                .map { .init(address: $0.contractAddress, server: $0.server) }
        }

        return deletedContracts
    }

    public func delegateContracts(forServer server: RPCServer) -> [AddressAndRPCServer] {
        var delegateContracts: [AddressAndRPCServer] = []
        store.performSync { realm in
            delegateContracts = Array(realm.objects(DelegateContract.self).filter("chainId = \(server.chainID)"))
                .map { .init(address: $0.contractAddress, server: $0.server) }
        }
        return delegateContracts
    }

    public func hiddenContracts(forServer server: RPCServer) -> [AddressAndRPCServer] {
        var hiddenContracts: [AddressAndRPCServer] = []
        store.performSync { realm in
            hiddenContracts = Array(realm.objects(HiddenContract.self).filter("chainId = \(server.chainID)"))
                .map { .init(address: $0.contractAddress, server: $0.server) }
        }
        return hiddenContracts
    }

    public func add(tokenUpdates updates: [TokenUpdate]) {
        guard !updates.isEmpty else { return }

        store.performSync { realm in
            try? realm.safeWrite {
                for token in updates {
                    let infoUpdate: [String: Any] = [
                        "uid": token.primaryKey
                    ]

                    let info = realm.create(TokenInfoObject.self, value: infoUpdate, update: .all)
                    //Even though primaryKey is provided, it is important to specific contract because this might be creating a new TokenObject instance from transactions
                    let update: [String: Any] = [
                        "primaryKey": token.primaryKey,
                        "contract": token.address.eip55String,
                        "chainId": token.server.chainID,
                        "name": token.name,
                        "symbol": token.symbol,
                        "decimals": token.decimals,
                        "rawType": token.tokenType.rawValue,
                        "_info": info
                    ]
                    realm.create(TokenObject.self, value: update, update: .all)
                }
            }
        }
    }

    public func addEthToken(forServer server: RPCServer) {
        store.performSync { realm in
            let etherToken = MultipleChainsTokensDataStore.functional.etherTokenObject(forServer: server)
            guard realm.object(ofType: TokenObject.self, forPrimaryKey: etherToken.primaryKey) == nil else { return }
            try? realm.safeWrite {
                self.addTokenWithoutCommitWrite(tokenObject: etherToken, realm: realm)
            }
        }
    }

    public func token(forContract contract: AlphaWallet.Address) -> Token? {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(contract: contract)

        var token: Token?
        store.performSync { realm in
            token = realm.objects(TokenObject.self)
                .filter(predicate)
                .first
                .map { Token(tokenObject: $0) }
        }

        return token
    }

    public func token(forContract contract: AlphaWallet.Address, server: RPCServer) -> Token? {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(server: server, contract: contract)

        var token: Token?

        store.performSync { realm in
            token = realm.objects(TokenObject.self)
                .filter(predicate)
                .first
                .map { Token(tokenObject: $0) }
        }

        return token
    }

    private func tokenObject(forContract contract: AlphaWallet.Address, server: RPCServer, realm: Realm) -> TokenObject? {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(server: server, contract: contract)

        return realm.objects(TokenObject.self)
            .filter(predicate)
            .first
    }

    @discardableResult public func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token] {
        guard !tokens.isEmpty else { return [] }

        var tokensToReturn: [Token] = []
        store.performSync { realm in
            let newTokens = tokens.compactMap { MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: $0, shouldUpdateBalance: shouldUpdateBalance) }
            try? realm.safeWrite {
                //TODO: save existed sort index and displaying state
                for token in newTokens {
                    self.addTokenWithoutCommitWrite(tokenObject: token, realm: realm)
                }
            }

            tokensToReturn = newTokens.map { Token(tokenObject: $0) }
        }

        return tokensToReturn
    }

    @discardableResult public func addOrUpdate(tokensOrContracts: [TokenOrContract]) -> [Token] {
        guard !tokensOrContracts.isEmpty else { return [] }

        store.performSync { realm in
            try? realm.safeWrite {
                for each in tokensOrContracts {
                    switch each {
                    case .delegateContracts(let values):
                        let delegateContract = values.map { DelegateContract(contractAddress: $0.address, server: $0.server) }

                        realm.add(delegateContract, update: .all)
                    case .ercToken(let token):
                        let tokenObject = MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: token, shouldUpdateBalance: token.type.shouldUpdateBalanceWhenDetected)
                        self.addTokenWithoutCommitWrite(tokenObject: tokenObject, realm: realm)
                    case .token(let token):
                        let tokenObject = TokenObject(token: token)
                        self.addTokenWithoutCommitWrite(tokenObject: tokenObject, realm: realm)
                    case .deletedContracts(let values):
                        let deadContracts = values.map { DelegateContract(contractAddress: $0.address, server: $0.server) }
                        realm.add(deadContracts, update: .all)
                    case .fungibleTokenComplete(let name, let symbol, let decimals, let contract, let server, let onlyIfThereIsABalance):
                        let existedTokenObject = self.tokenObject(forContract: contract, server: server, realm: realm)

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
                        self.addTokenWithoutCommitWrite(tokenObject: tokenObject, realm: realm)
                    case .none:
                        break
                    }
                }
            }
        }

        let tokenObjects = tokensOrContracts
            .compactMap { $0.addressAndRPCServer }
            .compactMap { token(forContract: $0.address, server: $0.server) }

        return tokenObjects
    }

    public func add(hiddenContracts: [AddressAndRPCServer]) {
        guard !hiddenContracts.isEmpty else { return }

        store.performSync { realm in
            try? realm.safeWrite {
                let hiddenContracts = hiddenContracts.map { HiddenContract(contractAddress: $0.address, server: $0.server) }
                realm.add(hiddenContracts, update: .all)
            }
        }
    }

    public func tokenBalancesTestsOnly() -> [TokenBalanceValue] {
        var balances: [TokenBalanceValue] = []
        store.performSync { realm in
            balances = realm.objects(TokenBalance.self).map { TokenBalanceValue(balance: $0) }
        }
        return balances
    }

    public func deleteTestsOnly(tokens: [Token]) {
        guard !tokens.isEmpty else { return }

        store.performSync { realm in
            try? realm.safeWrite {
                let tokendToDelete = tokens.compactMap { realm.object(ofType: TokenObject.self, forPrimaryKey: $0.primaryKey) }
                realm.delete(tokendToDelete)
            }
        }
    }

    @discardableResult public func addOrUpdate(_ actions: [AddOrUpdateTokenAction]) -> Bool? {
        guard !actions.isEmpty else { return nil }

        var result: Bool?
        store.performSync { realm in
            try? realm.safeWrite {
                for each in actions {
                    var value: Bool?
                    switch each {
                    case .add(let token, let shouldUpdateBalance):
                        let newToken = MultipleChainsTokensDataStore.functional.createTokenObject(ercToken: token, shouldUpdateBalance: shouldUpdateBalance)
                        self.addTokenWithoutCommitWrite(tokenObject: newToken, realm: realm)
                        value = true
                    case .update(let tokenObject, let action):
                        value = self.updateTokenWithoutCommitWrite(primaryKey: tokenObject.primaryKey, action: action, realm: realm)
                    }

                    if result == nil {
                        result = value
                    }
                }
            }
        }
        return result
    }

    @discardableResult public func updateToken(primaryKey: String, action: TokenUpdateAction) -> Bool? {
        var result: Bool?
        store.performSync { realm in
            try? realm.safeWrite {
                result = self.updateTokenWithoutCommitWrite(primaryKey: primaryKey, action: action, realm: realm)
            }
        }

        return result
    }

    private func addTokenWithoutCommitWrite(tokenObject: TokenObject, realm: Realm) {
        //TODO: save existed sort index and displaying state
        if let object = realm.object(ofType: TokenObject.self, forPrimaryKey: tokenObject.primaryKey) {
            tokenObject.sortIndex = object.sortIndex
            tokenObject.shouldDisplay = object.shouldDisplay
        }

        realm.add(tokenObject, update: .all)
    }

    @discardableResult private func updateTokenWithoutCommitWrite(primaryKey: String, action: TokenUpdateAction, realm: Realm) -> Bool? {
        guard let tokenObject = realm.object(ofType: TokenObject.self, forPrimaryKey: primaryKey) else { return nil }

        var result: Bool = false

        switch action {
        case .value(let value):
            return updateFungibleBalance(balance: value, token: tokenObject)
        case .nonFungibleBalance(let balance):
            return updateNonFungibleBalance(balance: balance, token: tokenObject, realm: realm)
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
        case .imageUrl(let url):
            if tokenObject._info?.imageUrl != url?.absoluteString {
                tokenObject._info?.imageUrl = url?.absoluteString
                result = true
            }
        case .coinGeckoTickerId(let id):
            if tokenObject._info?.coinGeckoId != id {
                tokenObject._info?.coinGeckoId = id
                result = true
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

    private func updateNonFungibleBalance(balance: NonFungibleBalance, token: TokenObject, realm: Realm) -> Bool {
        var hasUpdatedBalance: Bool = false

        //NOTE: add new balances
        let balancesToAdd = balance.rawValue
            .filter { b in !token.balance.contains(where: { v in v.balance == b }) }
            .map { TokenBalance(balance: $0) }

        //NOTE: remove old balances if something has changed
        let balancesToDelete = Array(token.balance
            .filter { !balance.rawValue.contains($0.balance) })

        if !balancesToDelete.isEmpty {
            realm.delete(balancesToDelete)
            hasUpdatedBalance = true
        }

        if !balancesToAdd.isEmpty {
            token.balance.append(objectsIn: balancesToAdd)
            hasUpdatedBalance = true
        }

        return hasUpdatedBalance
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

extension MultipleChainsTokensDataStore: DetectedContractsProvideble {
    public func alreadyAddedContracts(for server: RPCServer) -> [AlphaWallet.Address] {
        enabledTokens(for: [server]).map { $0.contractAddress }
    }

    public func deletedContracts(for server: RPCServer) -> [AlphaWallet.Address] {
        deletedContracts(forServer: server).map { $0.address }
    }

    public func hiddenContracts(for server: RPCServer) -> [AlphaWallet.Address] {
        hiddenContracts(forServer: server).map { $0.address }
    }

    public func delegateContracts(for server: RPCServer) -> [AlphaWallet.Address] {
        delegateContracts(forServer: server).map { $0.address }
    }
}

extension TokenObject {
    var addressAndRPCServer: AddressAndRPCServer {
        return .init(address: contractAddress, server: server)
    }
}

extension MultipleChainsTokensDataStore {
    public class functional {}
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

    static func etherTokenObject(forServer server: RPCServer) -> TokenObject {
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

    public static func etherToken(forServer server: RPCServer) -> Token {
        return Token(
                contract: Constants.nativeCryptoAddressInDatabase,
                server: server,
                name: server.name,
                symbol: server.symbol,
                decimals: server.decimals,
                value: .zero,
                type: .nativeCryptocurrency
        )
    }

    //TODO might be best to remove ethToken(for:) and just use token(for:) if possible, but careful with the contract value returned for .ether
    public static func token(forServer server: RPCServer) -> Token {
        return Token(
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
            token.balance.rawValue.forEach { balance in
                newToken.balance.append(TokenBalance(balance: balance))
            }
        }

        return newToken
    }

    public static func erc20AddressForNativeTokenFilter(servers: [RPCServer], tokens: [Token]) -> [Token] {
        var result = tokens
        for server in servers {
            if let address = server.erc20AddressForNativeToken, result.contains(where: { $0.contractAddress.sameContract(as: address) }) {
                result = result.filter { !$0.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) && $0.server == server }
            } else {
                continue
            }
        }

        return result
    }

    public static func recreateMissingInfoTokenObjects(for store: RealmStore) {
        store.performSync { realm in
            let predicate = NSPredicate(format: "_info == nil")
            let nilInfoResult = realm.objects(TokenObject.self).filter(predicate)
            guard !nilInfoResult.isEmpty else { return }

            try? realm.safeWrite {
                for each in nilInfoResult {
                    each._info = realm.object(ofType: TokenInfoObject.self, forPrimaryKey: each.primaryKey) ?? TokenInfoObject(uid: each.primaryKey)
                }
            }
        }
    }
}
