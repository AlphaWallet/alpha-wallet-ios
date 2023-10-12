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
    func token(for contract: AlphaWallet.Address) async -> Token?
    func token(for contract: AlphaWallet.Address, server: RPCServer) async -> Token?
    func tokensChangesetPublisher(for servers: [RPCServer], predicate: NSPredicate?) -> AnyPublisher<ChangeSet<[Token]>, Never>
    func tokens(for servers: [RPCServer]) async -> [Token]
    func delegateContractsChangeset(for servers: [RPCServer]) -> AnyPublisher<ChangeSet<[AddressAndRPCServer]>, Never>
    func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, DataStoreError>
    func deletedContracts(forServer server: RPCServer) async -> [AddressAndRPCServer]
    func delegateContracts(forServer server: RPCServer) async -> [AddressAndRPCServer]
    func hiddenContracts(forServer server: RPCServer) async -> [AddressAndRPCServer]
    func addEthToken(forServer server: RPCServer)
    func add(hiddenContracts: [AddressAndRPCServer])
    func deleteTestsOnly(tokens: [Token]) -> Task<Void, Never>
    func tokenBalancesTestsOnly() async -> [TokenBalanceValue]
    //TODO probably shouldn't/wouldn't be optional
    @discardableResult func updateToken(primaryKey: String, action: TokenFieldUpdate) async -> Bool?
    @discardableResult func addOrUpdate(with actions: [AddOrUpdateTokenAction]) async -> [Token]
}

extension TokensDataStore {

    @discardableResult func updateToken(addressAndRpcServer: AddressAndRPCServer, action: TokenFieldUpdate) async -> Bool? {
        let primaryKey = TokenObject.generatePrimaryKey(fromContract: addressAndRpcServer.address, server: addressAndRpcServer.server)
        return await updateToken(primaryKey: primaryKey, action: action)
    }

    func initialOrNewTokensPublisher(for servers: [RPCServer]) -> AnyPublisher<[Token], Never> {
        return tokensChangesetPublisher(for: servers, predicate: nil)
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
        return tokensChangesetPublisher(for: servers, predicate: nil)
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
    /// ercToken - tokens meta data
    case ercToken(ErcToken)
    /// delegateContracts - partially detect contract data and its rpc server
    case delegateContracts([AddressAndRPCServer])
    /// deletedContracts - failed to detect contact and its rpc server
    case deletedContracts([AddressAndRPCServer])
}

public enum AddOrUpdateTokenAction {
    /// - ercToken - erc meta information for token creating
    /// - shouldUpdateBalance - should be non fungible/ semifungible balance unpdated
    case add(ercToken: ErcToken, shouldUpdateBalance: Bool)
    /// - action - update some of tokens fields, nil for create a new token or update if its already exists
    /// - token - token to update
    case update(token: Token, field: TokenFieldUpdate?)
    /// delegateContracts - partially detect contract data and its rpc server
    case addOrUpdateDelegateContracts(delegateContracts: [AddressAndRPCServer])
    /// deletedContracts - failed to detect contact and its rpc server
    case addOrUpdateDeletedContracts(deletedContracts: [AddressAndRPCServer])
    /// delegateContracts - partially detect contract data and its rpc server
    case deleteDeletedContracts(deletedContracts: [AddressAndRPCServer])

    public init(_ token: Token) {
        self = .update(token: token, field: nil)
    }

    public init(_ token: TokenOrContract) {
        switch token {
        case .ercToken(let token):
            self = .add(ercToken: token, shouldUpdateBalance: false)
        case .deletedContracts(let array):
            self = .addOrUpdateDeletedContracts(deletedContracts: array)
        case .delegateContracts(let array):
            self = .addOrUpdateDelegateContracts(delegateContracts: array)
        }
    }
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

public enum TokenFieldUpdate {
    case value(BigUInt)
    case isDisabled(Bool)
    case nonFungibleBalance(NonFungibleBalance)
    case name(String)
    case type(TokenType)
    case isHidden(Bool)
    case imageUrl(URL?)
    case coinGeckoTickerId(String)
}

// swiftlint:disable type_body_length
open class MultipleChainsTokensDataStore: NSObject, TokensDataStore {
    private let store: RealmStore
    private var cancellables = Set<AnyCancellable>()
    private var notificationTokens: Set<NotificationToken> = []

    public init(store: RealmStore) {
        self.store = store
        super.init()

        MultipleChainsTokensDataStore.functional.recreateMissingInfoTokenObjects(for: store)
    }

    public func tokensChangesetPublisher(for servers: [RPCServer], predicate: NSPredicate?) -> AnyPublisher<ChangeSet<[Token]>, Never> {
        let publisher = PassthroughSubject<ChangeSet<[Token]>, Never>()
        Task {
            await store.performSync { realm in
                self.enabledTokenObjectResults(forServers: servers, predicate: predicate, realm: realm)
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
                    }.sink { value in
                        publisher.send(value)
                    }.store(in: &self.cancellables)
            }
        }
        return publisher.eraseToAnyPublisher()
    }

    public func delegateContractsChangeset(for servers: [RPCServer]) -> AnyPublisher<ChangeSet<[AddressAndRPCServer]>, Never> {
        let publisher = PassthroughSubject<ChangeSet<[AddressAndRPCServer]>, Never>()
        Task {
            await store.performSync { realm in
                realm.objects(DelegateContract.self)
                    .filter(MultipleChainsTokensDataStore.functional.chainIdPredicate(servers: servers))
                    .changesetPublisher
                    .freeze()
                    .receive(on: DispatchQueue.global())
                    .map { change in
                        switch change {
                        case .initial(let contracts):
                            let contracts = Array(contracts).map { AddressAndRPCServer(address: $0.contractAddress, server: $0.server) }
                            return .initial(contracts)
                        case .update(let contracts, let deletions, let insertions, let modifications):
                            let contracts = Array(contracts).map { AddressAndRPCServer(address: $0.contractAddress, server: $0.server) }
                            return .update(contracts, deletions: deletions, insertions: insertions, modifications: modifications)
                        case .error(let error):
                            return .error(error)
                        }
                    }.sink { value in
                        publisher.send(value)
                    }.store(in: &self.cancellables)
            }
        }

        return publisher.eraseToAnyPublisher()
    }

    public func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, DataStoreError> {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(server: server, contract: contract)

        //We don't want the initial `nil`, it's wrong (and unnecessary) since we are just waiting for the database read to get an actual value, so we must not use CurrentValueSubject
        let publisher: PassthroughSubject<Token?, DataStoreError> = .init()

        Task {
            var notificationToken: NotificationToken?
            await store.perform { realm in
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
                if let notificationToken {
                    self.notificationTokens.insert(notificationToken)
                }
            }
            publisher.handleEvents(receiveCancel: { [weak self] in
                if let notificationToken {
                    notificationToken.invalidate()
                    if let strongSelf = self {
                        strongSelf.notificationTokens = strongSelf.notificationTokens.filter { $0 != notificationToken }
                    }
                }
            })
        }

        return publisher.eraseToAnyPublisher()
    }

    public func tokens(for servers: [RPCServer]) async -> [Token] {
        var tokensToReturn: [Token] = []
        await store.perform { realm in
            let tokens = Array(self.enabledTokenObjectResults(forServers: servers, predicate: nil, realm: realm).map { Token(tokenObject: $0) })
            tokensToReturn = MultipleChainsTokensDataStore.functional.erc20AddressForNativeTokenFilter(servers: servers, tokens: tokens)
        }

        return tokensToReturn
    }

    public func deletedContracts(forServer server: RPCServer) async -> [AddressAndRPCServer] {
        var deletedContracts: [AddressAndRPCServer] = []
        await store.perform { realm in
            deletedContracts = Array(realm.objects(DeletedContract.self).filter("chainId = \(server.chainID)"))
                .map { .init(address: $0.contractAddress, server: $0.server) }
        }

        return deletedContracts
    }

    public func delegateContracts(forServer server: RPCServer) async -> [AddressAndRPCServer] {
        var delegateContracts: [AddressAndRPCServer] = []
        await store.perform { realm in
            delegateContracts = Array(realm.objects(DelegateContract.self).filter("chainId = \(server.chainID)"))
                .map { .init(address: $0.contractAddress, server: $0.server) }
        }
        return delegateContracts
    }

    public func hiddenContracts(forServer server: RPCServer) async -> [AddressAndRPCServer] {
        var hiddenContracts: [AddressAndRPCServer] = []
        await store.perform { realm in
            hiddenContracts = Array(realm.objects(HiddenContract.self).filter("chainId = \(server.chainID)"))
                .map { .init(address: $0.contractAddress, server: $0.server) }
        }
        return hiddenContracts
    }

    public func addEthToken(forServer server: RPCServer) {
        Task {
            await store.perform { realm in
                let etherToken = TokenObject(token: MultipleChainsTokensDataStore.functional.etherToken(forServer: server))
                guard realm.object(ofType: TokenObject.self, forPrimaryKey: etherToken.primaryKey) == nil else { return }
                try? realm.safeWrite {
                    self.addTokenWithoutCommitWrite(tokenObject: etherToken, realm: realm)
                }
            }
        }
    }

    public func token(for contract: AlphaWallet.Address) async -> Token? {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(contract: contract)

        var token: Token?
        await store.perform { realm in
            token = realm.objects(TokenObject.self)
                .filter(predicate)
                .first
                .map { Token(tokenObject: $0) }
        }

        return token
    }

    public func token(for contract: AlphaWallet.Address, server: RPCServer) async -> Token? {
        let predicate = MultipleChainsTokensDataStore
            .functional
            .tokenPredicate(server: server, contract: contract)

        var token: Token?

        await store.perform { realm in
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

    public func add(hiddenContracts: [AddressAndRPCServer]) {
        guard !hiddenContracts.isEmpty else { return }

        Task {
            await store.perform { realm in
                try? realm.safeWrite {
                    let hiddenContracts = hiddenContracts.map { HiddenContract(contractAddress: $0.address, server: $0.server) }
                    realm.add(hiddenContracts, update: .all)
                }
            }
        }
    }

    public func tokenBalancesTestsOnly() async -> [TokenBalanceValue] {
        var balances: [TokenBalanceValue] = []
        await store.perform { realm in
            balances = realm.objects(TokenBalance.self).map { TokenBalanceValue(balance: $0) }
        }
        return balances
    }

    public func deleteTestsOnly(tokens: [Token]) -> Task<Void, Never> {
        guard !tokens.isEmpty else { return Task {} }

        return Task {
            await store.perform { realm in
                try? realm.safeWrite {
                    let tokendToDelete = tokens.compactMap { realm.object(ofType: TokenObject.self, forPrimaryKey: $0.primaryKey) }
                    realm.delete(tokendToDelete)
                }
            }
        }
    }

    @discardableResult public func addOrUpdate(with actions: [AddOrUpdateTokenAction]) async -> [Token] {
        guard !actions.isEmpty else { return [] }

        var tokens: [Token] = []
        await store.perform { realm in
            try? realm.safeWrite {
                for each in actions {
                    switch each {
                    case .add(let token, let shouldUpdateBalance):
                        let tokenObject = TokenObject(ercToken: token, shouldUpdateBalance: shouldUpdateBalance)
                        self.addTokenWithoutCommitWrite(tokenObject: tokenObject, realm: realm)

                        if let tokenObject = self.tokenObject(forContract: token.contract, server: token.server, realm: realm) {
                            tokens += [Token(tokenObject: tokenObject)]
                        }
                    case .update(let token, let action):
                        if let action = action {
                            self.updateTokenWithoutCommitWrite(primaryKey: token.primaryKey, action: action, realm: realm)
                        } else {
                            self.addTokenWithoutCommitWrite(tokenObject: TokenObject(token: token), realm: realm)
                        }
                        if let tokenObject = self.tokenObject(forContract: token.contractAddress, server: token.server, realm: realm) {
                            tokens += [Token(tokenObject: tokenObject)]
                        }
                    case .addOrUpdateDelegateContracts(let delegateContracts):
                        let delegateContracts = delegateContracts.map { DelegateContract(contractAddress: $0.address, server: $0.server) }
                        realm.add(delegateContracts, update: .all)
                    case .addOrUpdateDeletedContracts(let deletedContracts):
                        let deletedContracts = deletedContracts.map { DeletedContract(contractAddress: $0.address, server: $0.server) }
                        realm.add(deletedContracts, update: .all)
                    case .deleteDeletedContracts(let deletedContracts):
                        let deletedContracts = deletedContracts.compactMap {
                            let pk = DeletedContract.primaryKey(contractAddress: $0.contractAddress, server: $0.server)
                            return realm.object(ofType: DeletedContract.self, forPrimaryKey: pk)
                        }
                        guard !deletedContracts.isEmpty else { continue }

                        realm.add(deletedContracts, update: .all)
                    }
                }
            }
        }
        return tokens
    }

    @discardableResult public func updateToken(primaryKey: String, action: TokenFieldUpdate) async -> Bool? {
        var result: Bool?
        await store.perform { realm in
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

    @discardableResult private func updateTokenWithoutCommitWrite(primaryKey: String, action: TokenFieldUpdate, realm: Realm) -> Bool? {
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

    private func updateFungibleBalance(balance value: BigUInt, token: TokenObject) -> Bool {
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

    private func enabledTokenObjectResults(forServers servers: [RPCServer], predicate: NSPredicate?, realm: Realm) -> Results<TokenObject> {
        let nonEmptyTokens = MultipleChainsTokensDataStore
            .functional
            .nonEmptyContractTokenPredicateWithErc20AddressForNativeTokenFilter(servers: servers, isDisabled: false)

        var predicates: [NSPredicate] = [nonEmptyTokens]
        if let predicate = predicate {
            predicates += [predicate]
        }

        return realm
            .objects(TokenObject.self)
            .filter(NSCompoundPredicate(andPredicateWithSubpredicates: predicates))
    }
}
// swiftlint:enable type_body_length

extension TokenObject {

    convenience init(ercToken token: ErcToken, shouldUpdateBalance: Bool) {
        self.init(contract: token.contract, server: token.server, name: token.name, symbol: token.symbol, decimals: token.decimals, value: token.value.description, isCustom: true, type: token.type)

        if shouldUpdateBalance {
            token.balance.rawValue.forEach { balance in
                self.balance.append(TokenBalance(balance: balance))
            }
        }
    }
}

extension TokenObject {
    var addressAndRPCServer: AddressAndRPCServer {
        return .init(address: contractAddress, server: server)
    }
}

extension MultipleChainsTokensDataStore {
    public enum functional {}
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

    public static func erc20AddressForNativeTokenFilter(servers: [RPCServer], tokens: [Token]) -> [Token] {
        var result = tokens
        for server in servers {
            if let address = server.erc20AddressForNativeToken, result.contains(where: { $0.contractAddress == address }) {
                result = result.filter { $0.contractAddress != Constants.nativeCryptoAddressInDatabase && $0.server == server }
            } else {
                continue
            }
        }

        return result
    }

    public static func recreateMissingInfoTokenObjects(for store: RealmStore) {
        Task {
            await store.perform { realm in
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
}
