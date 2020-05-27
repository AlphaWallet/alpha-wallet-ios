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

protocol TokensDataStoreDelegate: class {
    func didUpdate(result: ResultResult<TokensViewModel, TokenError>.t, refreshImmediately: Bool)
}

// swiftlint:disable type_body_length
class TokensDataStore {
    private lazy var getNameCoordinator: GetNameCoordinator = {
        return GetNameCoordinator(forServer: server)
    }()

    private lazy var getSymbolCoordinator: GetSymbolCoordinator = {
        return GetSymbolCoordinator(forServer: server)
    }()

    private lazy var getNativeCryptoCurrencyBalanceCoordinator: GetNativeCryptoCurrencyBalanceCoordinator = {
        return GetNativeCryptoCurrencyBalanceCoordinator(forServer: server)
    }()

    private lazy var getERC20BalanceCoordinator: GetERC20BalanceCoordinator = {
        return GetERC20BalanceCoordinator(forServer: server)
    }()

    private lazy var getERC875BalanceCoordinator: GetERC875BalanceCoordinator = {
        return GetERC875BalanceCoordinator(forServer: server)
    }()

    private lazy var getERC721ForTicketsBalanceCoordinator: GetERC721ForTicketsBalanceCoordinator = {
        return GetERC721ForTicketsBalanceCoordinator(forServer: server)
    }()

    private lazy var getIsERC875ContractCoordinator: GetIsERC875ContractCoordinator = {
        return GetIsERC875ContractCoordinator(forServer: server)
    }()

    private lazy var getERC721BalanceCoordinator: GetERC721BalanceCoordinator = {
        return GetERC721BalanceCoordinator(forServer: server)
    }()

    private lazy var getIsERC721ForTicketsContractCoordinator: GetIsERC721ForTicketsContractCoordinator = {
        return GetIsERC721ForTicketsContractCoordinator(forServer: server)
    }()

    private lazy var getIsERC721ContractCoordinator: GetIsERC721ContractCoordinator = {
        return GetIsERC721ContractCoordinator(forServer: server)
    }()

    private lazy var getDecimalsCoordinator: GetDecimalsCoordinator = {
        return GetDecimalsCoordinator(forServer: server)
    }()

    private let provider = AlphaWalletProviderFactory.makeProvider()
    private let filterTokensCoordinator: FilterTokensCoordinator
    private let account: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private let realm: Realm
    private var pricesTimer = Timer()
    private var ethTimer = Timer()
    //We should refresh prices every 5 minutes.
    private let intervalToRefreshPrices = 300.0
    //We should refresh balance of the ETH every 10 seconds.
    private let intervalToETHRefresh = 10.0

    private var chainId: Int {
        return server.chainID
    }
    private var isFetchingPrices = false
    private let config: Config
    private let openSea: OpenSea

    let server: RPCServer
    weak var delegate: TokensDataStoreDelegate?
    //TODO why is this a dictionary? There seems to be only at most 1 key-value pair in the dictionary
    var tickers: [AlphaWallet.Address: CoinTicker]? = .none
    var tokensModel: Subscribable<[TokenObject]> = Subscribable(nil)

    var objects: [TokenObject] {
        return Array(
                realm.objects(TokenObject.self)
                        .filter("chainId = \(self.chainId)")
                        .filter("contract != ''")
        )
    }

    //TODO might be good to change `enabledObject` to just return the streaming list from Realm instead of a Swift native Array and other properties/callers can convert to Array if necessary
    var enabledObject: [TokenObject] {
        return Array(realm.objects(TokenObject.self)
                .filter("chainId = \(self.chainId)")
                .filter("isDisabled = false"))
    }

    var deletedContracts: [DeletedContract] {
        return Array(realm.objects(DeletedContract.self)
                .filter("chainId = \(self.chainId)"))
    }

    var delegateContracts: [DelegateContract] {
        return Array(realm.objects(DelegateContract.self)
                .filter("chainId = \(self.chainId)"))
    }

    var hiddenContracts: [HiddenContract] {
        return Array(realm.objects(HiddenContract.self)
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

    init(
            realm: Realm,
            account: Wallet,
            server: RPCServer,
            config: Config,
            assetDefinitionStore: AssetDefinitionStore,
            filterTokensCoordinator: FilterTokensCoordinator
    ) {
        self.filterTokensCoordinator = filterTokensCoordinator
        self.account = account
        self.server = server
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.realm = realm
        self.openSea = OpenSea.createInstance(forServer: server)
        self.addEthToken()

        //TODO not needed for setupCallForAssetAttributeCoordinators? Look for other callers of DataStore.updateDelegate
        self.scheduledTimerForPricesUpdate()
        self.scheduledTimerForEthBalanceUpdate()
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
        updatePrices()
        refreshBalance()
    }

    func getContractName(for address: AlphaWallet.Address,
                         completion: @escaping (ResultResult<String, AnyError>.t) -> Void) {
        getNameCoordinator.getName(for: address) { (result) in
            completion(result)
        }
    }

    func getContractSymbol(for address: AlphaWallet.Address,
                           completion: @escaping (ResultResult<String, AnyError>.t) -> Void) {
        getSymbolCoordinator.getSymbol(for: address) { result in
            completion(result)
        }
    }

    func getDecimals(for address: AlphaWallet.Address,
                     completion: @escaping (ResultResult<UInt8, AnyError>.t) -> Void) {
        getDecimalsCoordinator.getDecimals(for: address) { result in
            completion(result)
        }
    }

    func getContractName(for address: AlphaWallet.Address) -> Promise<String> {
        return Promise { seal in
            getNameCoordinator.getName(for: address) { (result) in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getContractSymbol(for address: AlphaWallet.Address) -> Promise<String> {
        return Promise { seal in
            getSymbolCoordinator.getSymbol(for: address) { result in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getDecimals(for address: AlphaWallet.Address) -> Promise<UInt8> {
        return Promise { seal in
            getDecimalsCoordinator.getDecimals(for: address) { result in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getTokenType(for address: AlphaWallet.Address) -> Promise<TokenType> {
        return Promise { seal in
            getTokenType(for: address) { tokenType in
                seal.fulfill(tokenType)
            }
        }
    }

    func getERC20Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void) {
        getERC20BalanceCoordinator.getBalance(for: account.address, contract: address) { result in
            completion(result)
        }
    }

    func getERC875Balance(for address: AlphaWallet.Address,
                          completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        getERC875BalanceCoordinator.getERC875TokenBalance(for: account.address, contract: address) { result in
            completion(result)
        }
    }

    func getERC721ForTicketsBalance(for address: AlphaWallet.Address,
                                    completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        getERC721ForTicketsBalanceCoordinator.getERC721ForTicketsTokenBalance(for: account.address, contract: address) { result in
            completion(result)
        }
    }

    func getIsERC875Contract(for address: AlphaWallet.Address,
                             completion: @escaping (ResultResult<Bool, AnyError>.t) -> Void) {
        getIsERC875ContractCoordinator.getIsERC875Contract(for: address) { result in
            completion(result)
        }
    }

    func getERC721Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        getERC721BalanceCoordinator.getERC721TokenBalance(for: account.address, contract: address) { result in
            switch result {
            case .success(let balance):
                if balance >= Int.max {
                    completion(.failure(AnyError(Web3Error(description: ""))))
                } else {
                    completion(.success([String](repeating: "0", count: Int(balance))))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func getTokensFromOpenSea() -> OpenSea.PromiseResult {
        //TODO when we no longer create multiple instances of TokensDataStore, we don't have to use singleton for OpenSea class. This was to avoid fetching multiple times from OpenSea concurrently
        return openSea.makeFetchPromise(forOwner: account.address)
    }

    func getTokenType(for address: AlphaWallet.Address,
                      completion: @escaping (TokenType) -> Void) {
        var knownToBeNotERC721 = false
        var knownToBeNotERC875 = false
        getIsERC875ContractCoordinator.getIsERC875Contract(for: address) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case .success(let isERC875):
                if isERC875 {
                    completion(.erc875)
                    return
                } else {
                    knownToBeNotERC875 = true
                }
            case .failure:
                knownToBeNotERC875 = true
            }
            if knownToBeNotERC721 && knownToBeNotERC875 {
                completion(.erc20)
            }
        }

        getIsERC721ContractCoordinator.getIsERC721Contract(for: address) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let isERC721):
                if isERC721 {
                    strongSelf.getIsERC721ForTicketsContractCoordinator.getIsERC721ForTicketContract(for: address) { result in
                        switch result {
                        case .success(let isERC721ForTickets):
                            if isERC721ForTickets {
                                completion(.erc721ForTickets)
                            } else {
                                completion(.erc721)
                            }
                        case .failure:
                            completion(.erc721)
                        }
                    }
                } else {
                    knownToBeNotERC721 = true
                }
            case .failure:
                knownToBeNotERC721 = true
            }
            if knownToBeNotERC721 && knownToBeNotERC875 {
                completion(.erc20)
            }
        }
    }

    func token(forContract contract: AlphaWallet.Address) -> TokenObject? {
        //TODO improved performance if contract is always stored as EIP55
        return realm.objects(TokenObject.self).first { contract.sameContract(as: $0.contract) && $0.chainId == chainId }
    }

    func refreshBalance() {
        //TODO updateDelegate() is needed so the data (eg. tokens in Wallet tab when app launches) can appear immediately (by reading from the database) while updated data is downloaded. Though it probably doesn't need to be called an additional time, every time. It is important to refresh immediately first, rather than be rate limited because we might be deleting (hiding) a token and the user should see the list of tokens refresh immediately
        updateDelegate(refreshImmediately: true)
        guard !enabledObject.isEmpty else {
            return
        }
        //TODO While we might want to improve it such as enabledObject still returning Realm's streaming list instead of a Swift array and filtering using predicates, it doesn't affect much here, yet.
        let etherToken = TokensDataStore.etherToken(forServer: server)
        let updateTokens = enabledObject.filter { $0 != etherToken }
        let nonERC721Tokens = updateTokens.filter { !$0.isERC721AndNotForTickets }
        let erc721Tokens = updateTokens.filter { $0.isERC721AndNotForTickets }
        refreshBalanceForTokensThatAreNotNonTicket721(tokens: nonERC721Tokens)
        refreshBalanceForERC721Tokens(tokens: erc721Tokens)
    }

    private func refreshBalanceForTokensThatAreNotNonTicket721(tokens: [TokenObject]) {
        assert(!tokens.contains { $0.isERC721AndNotForTickets })
        var count = 0
        //So we refresh the UI. Possible improvement is to refresh earlier, but still refresh at the end
        func incrementCountAndUpdateDelegate() {
            count += 1
            if count == tokens.count {
                updateDelegate()
            }
        }
        for tokenObject in tokens {
            switch tokenObject.type {
            case .nativeCryptocurrency:
                incrementCountAndUpdateDelegate()
            case .erc20:
                getERC20Balance(for: tokenObject.contractAddress, completion: { [weak self] result in
                    defer { incrementCountAndUpdateDelegate() }
                    guard let strongSelf = self else { return }
                    switch result {
                    case .success(let balance):
                        strongSelf.update(token: tokenObject, action: .value(balance))
                    case .failure:
                        break
                    }
                })
            case .erc875:
                getERC875Balance(for: tokenObject.contractAddress, completion: { [weak self] result in
                    defer { incrementCountAndUpdateDelegate() }
                    guard let strongSelf = self else { return }
                    switch result {
                    case .success(let balance):
                        strongSelf.update(token: tokenObject, action: .nonFungibleBalance(balance))
                    case .failure:
                        break
                    }
                })
            case .erc721:
                break
            case .erc721ForTickets:
                getERC721ForTicketsBalance(for: tokenObject.contractAddress, completion: { [weak self] result in
                    defer { incrementCountAndUpdateDelegate() }
                    guard let strongSelf = self else { return }
                    switch result {
                    case .success(let balance):
                        strongSelf.update(token: tokenObject, action: .nonFungibleBalance(balance))
                    case .failure:
                        break
                    }
                })
            }
        }
    }

    private func refreshBalanceForERC721Tokens(tokens: [TokenObject]) {
        assert(!tokens.contains { !$0.isERC721AndNotForTickets })
        guard OpenSea.isServerSupported(server) else { return }
        getTokensFromOpenSea().done { [weak self] contractToOpenSeaNonFungibles in
            guard let strongSelf = self else { return }
            let erc721ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0 }
            let erc721ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721ContractsFoundInOpenSea
            var count = 0
            for address in erc721ContractsNotFoundInOpenSea {
                strongSelf.getERC721Balance(for: address) { [weak self] result in
                    guard let strongSelf = self else { return }
                    defer {
                        count += 1
                        if count == erc721ContractsNotFoundInOpenSea.count {
                            strongSelf.updateDelegate()
                        }
                    }
                    switch result {
                    case .success(let balance):
                        if let token = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
                            strongSelf.update(token: token, action: .nonFungibleBalance(balance))
                        }
                    case .failure:
                        break
                    }
                }
            }

            for (contract, openSeaNonFungibles) in contractToOpenSeaNonFungibles {
                var listOfJson = [String]()
                var anyNonFungible: OpenSeaNonFungible?
                for each in openSeaNonFungibles {
                    if let encodedJson = try? JSONEncoder().encode(each), let jsonString = String(data: encodedJson, encoding: .utf8) {
                        anyNonFungible = each
                        listOfJson.append(jsonString)
                    } else {
                        NSLog("Failed to convert ERC721 token from OpenSea to JSON")
                    }
                }

                if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) {
                    switch tokenObject.type {
                    case .nativeCryptocurrency, .erc721, .erc875, .erc721ForTickets:
                        break
                    case .erc20:
                        strongSelf.update(token: tokenObject, action: .type(.erc721))
                    }
                    strongSelf.update(token: tokenObject, action: .nonFungibleBalance(listOfJson))
                    if let anyNonFungible = anyNonFungible {
                        strongSelf.update(token: tokenObject, action: .name(anyNonFungible.contractName))
                    }
                } else {
                    let token = ERCToken(
                            contract: contract,
                            server: strongSelf.server,
                            name: openSeaNonFungibles[0].contractName,
                            symbol: openSeaNonFungibles[0].symbol,
                            decimals: 0,
                            type: .erc721,
                            balance: listOfJson
                    )
                    strongSelf.addCustom(token: token)
                }
            }
            strongSelf.updateDelegate()
        }.catch {
            NSLog("Failed to retrieve tokens from OpenSea: \($0)")
        }
    }

    func refreshETHBalance() {
        getNativeCryptoCurrencyBalanceCoordinator.getBalance(for: account.address) {  [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let balance):
                //Defensive check, instead of force unwrapping the result. At least one crash due to token being nil. Perhaps a Realm bug or in our code, perhaps in between enabling/disabling of chains? Harmless to do an early return
                guard let token = strongSelf.token(forContract: Constants.nativeCryptoAddressInDatabase) else { return }
                //TODO why is each chain's balance updated so many times? (if we add console logs)
                strongSelf.update(token: token, action: .value(balance.value))
                strongSelf.updateDelegate()
            case .failure: break
            }
        }
    }

    private func updateDelegate(refreshImmediately: Bool = false) {
        tokensModel.value = enabledObject
        var tickersForThisServer = [RPCServer: [AlphaWallet.Address: CoinTicker]]()
        tickersForThisServer[server] = tickers
        let tokensViewModel = TokensViewModel(filterTokensCoordinator: filterTokensCoordinator, tokens: enabledObject, tickers: tickersForThisServer)
        delegate?.didUpdate(result: .success( tokensViewModel ), refreshImmediately: refreshImmediately)
    }

    func coinTicker(for token: TokenObject) -> CoinTicker? {
        return tickers?[token.contractAddress]
    }

    func addCustom(token: ERCToken) {
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
    }

    func updatePricesAfterComingOnline() {
        updatePrices()
    }

    func updatePrices() {
        guard let priceToUpdate = getPriceToUpdate() else { return }
        guard !isFetchingPrices else { return }
        isFetchingPrices = true
        provider.request(priceToUpdate) { [weak self] result in
            guard let strongSelf = self else { return }
            defer {
                strongSelf.isFetchingPrices = false
            }
            guard case .success(let response) = result else { return }
            do {
                let tickers = try response.map([CoinTicker].self, using: JSONDecoder())
                let tempTickers = tickers.reduce([String: CoinTicker]()) { (dict, ticker) -> [String: CoinTicker] in
                    var dict = dict
                    dict[ticker.contract] = ticker
                    return dict
                }
                var resultTickers = [AlphaWallet.Address: CoinTicker]()
                for (contract, ticker) in tempTickers {
                    guard let contractAddress = AlphaWallet.Address(uncheckedAgainstNullAddress: contract) else { continue }
                    resultTickers[contractAddress] = ticker
                }
                strongSelf.tickers = resultTickers
                //TODO is it better if we pass in an enum to indicate what's the change? if crypto price change, we only need to refresh the native crypto currency cards?
                strongSelf.updateDelegate()
            } catch { }
        }
    }

    private func getPriceToUpdate() -> AlphaWalletService? {
        switch server {
        case .main:
            return .priceOfEth(config: config)
        case .xDai:
            return .priceOfDai(config: config)
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .custom:
            return nil
        }
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
            DispatchQueue.global().async {
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

    enum TokenBalanceUpdateAction {
        case updateJsonProperty(String, Any)
    }

    ///Note that it's possible for a contract to have the same tokenId repeated
    func update(contract: AlphaWallet.Address, tokenId: String, action: TokenBalanceUpdateAction) {
        guard let token = token(forContract: contract) else { return }
        let tokenIdInt = BigUInt(tokenId.drop0x, radix: 16)
        let balances = token.balance.filter { BigUInt($0.balance.drop0x, radix: 16) == tokenIdInt }

        try! realm.write {
            switch action {
            case .updateJsonProperty(let key, let value):
                for each in balances {
                    let json = each.json
                    if let data = json.data(using: .utf8), var dictionary = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) {
                        dictionary[key] = value
                        if let updatedData = try? JSONSerialization.data(withJSONObject: dictionary), let updatedJson = String(data: updatedData, encoding: .utf8) {
                            each.json = updatedJson
                        }
                    }
                }
            }
        }
    }

    func jsonAttributeValue(forContract contract: AlphaWallet.Address, tokenId: String, attributeId: String) -> Any? {
        guard let token = token(forContract: contract) else { return nil }
        let tokenIdInt = BigUInt(tokenId.drop0x, radix: 16)
        guard let balance = token.balance.first(where: { BigUInt($0.balance.drop0x, radix: 16) == tokenIdInt }) else { return nil }
        let json = balance.json
        if let data = json.data(using: .utf8), var dictionary = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) {
            return dictionary[attributeId]
        } else {
            return nil
        }
    }

    private func scheduledTimerForPricesUpdate() {
        guard !config.isAutoFetchingDisabled else { return }
        updatePrices()
        pricesTimer = Timer.scheduledTimer(timeInterval: intervalToRefreshPrices, target: BlockOperation { [weak self] in
            self?.updatePrices()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }
    private func scheduledTimerForEthBalanceUpdate() {
        guard !config.isAutoFetchingDisabled else { return }
        ethTimer = Timer.scheduledTimer(timeInterval: intervalToETHRefresh, target: BlockOperation { [weak self] in
            self?.refreshETHBalance()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }

    private func updateTokenName(token: TokenObject, to name: String) {
        try! realm.write {
            token.name = name
        }
    }

    deinit {
        //We should make sure that timer is invalidate.
        pricesTimer.invalidate()
        ethTimer.invalidate()
    }
}
// swiftlint:enable type_body_length
