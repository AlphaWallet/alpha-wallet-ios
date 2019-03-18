// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import Result
import RealmSwift
import SwiftyJSON
import TrustKeystore

enum TokenError: Error {
    case failedToFetch
}

protocol TokensDataStoreDelegate: class {
    func didUpdate(result: ResultResult<TokensViewModel, TokenError>.t)
}

class TokensDataStore {
    private lazy var getBalanceCoordinator: GetBalanceCoordinator = {
        return GetBalanceCoordinator(config: config)
    }()

    private lazy var getNameCoordinator: GetNameCoordinator = {
        return GetNameCoordinator(config: config)
    }()

    private lazy var getSymbolCoordinator: GetSymbolCoordinator = {
        return GetSymbolCoordinator(config: config)
    }()

    private lazy var getERC875BalanceCoordinator: GetERC875BalanceCoordinator = {
        return GetERC875BalanceCoordinator(config: config)
    }()

    private lazy var getIsERC875ContractCoordinator: GetIsERC875ContractCoordinator = {
        return GetIsERC875ContractCoordinator(config: config)
    }()

    private lazy var getERC721BalanceCoordinator: GetERC721BalanceCoordinator = {
        return GetERC721BalanceCoordinator(config: config)
    }()

    private lazy var getIsERC721ContractCoordinator: GetIsERC721ContractCoordinator = {
        return GetIsERC721ContractCoordinator(config: config)
    }()

    private lazy var getDecimalsCoordinator: GetDecimalsCoordinator = {
        return GetDecimalsCoordinator(config: config)
    }()

    private let provider = AlphaWalletProviderFactory.makeProvider()

    private let account: Wallet
    private let config: Config
    private let assetDefinitionStore: AssetDefinitionStore
    private let realm: Realm
    private var pricesTimer = Timer()
    private var ethTimer = Timer()
    //We should refresh prices every 5 minutes.
    private let intervalToRefreshPrices = 300.0
    //We should refresh balance of the ETH every 10 seconds.
    private let intervalToETHRefresh = 10.0

    weak var delegate: TokensDataStoreDelegate?
    //TODO why is this a dictionary? There seems to be only at most 1 key-value pair in the dictionary
    var tickers: [String: CoinTicker]? = .none
    var tokensModel: Subscribable<[TokenObject]> = Subscribable(nil)

    var objects: [TokenObject] {
        return realm.objects(TokenObject.self)
                .sorted(byKeyPath: "contract", ascending: true)
                .filter { !$0.contract.isEmpty }
    }

    var enabledObject: [TokenObject] {
        return realm.objects(TokenObject.self)
                .sorted(byKeyPath: "contract", ascending: true)
                .filter { !$0.isDisabled }
    }

    var deletedContracts: [DeletedContract] {
        return Array(realm.objects(DeletedContract.self))
    }

    var delegateContracts: [DelegateContract] {
        return Array(realm.objects(DelegateContract.self))
    }

    var hiddenContracts: [HiddenContract] {
        return Array(realm.objects(HiddenContract.self))
    }

    static func etherToken(for config: Config) -> TokenObject {
        return TokenObject(
            contract: Constants.nullAddress,
            name: config.server.name,
            symbol: config.server.symbol,
            decimals: config.server.decimals,
            value: "0",
            isCustom: false,
            type: .nativeCryptocurrency
        )
    }

    //TODO might be best to remove ethToken(for:) and just use token(for:) if possible, but careful with the contract value returned for .ether
    static func token(for config: Config) -> TokenObject {
        return TokenObject(
                contract: config.server.priceID.description,
                name: config.server.name,
                symbol: config.server.symbol,
                decimals: config.server.decimals,
                value: "0",
                isCustom: false,
                type: .nativeCryptocurrency
        )
    }

    init(
            realm: Realm,
            account: Wallet,
            config: Config,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.account = account
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.realm = realm
        self.addEthToken()
        self.scheduledTimerForPricesUpdate()
        self.scheduledTimerForEthBalanceUpdate()

        fetchTokenNamesForNonFungibleTokensIfEmpty()
    }

    private func addEthToken() {
        //Check if we have previos values.
        let etherToken = TokensDataStore.etherToken(for: config)
        if objects.first(where: { $0 == etherToken }) == nil {
            add(tokens: [etherToken])
        }
    }

    static func update(in realm: Realm, tokens: [TokenUpdate]) {
        realm.beginWrite()
        for token in tokens {
            let update: [String: Any] = [
                "contract": token.address.description,
                "name": token.name,
                "symbol": token.symbol,
                "decimals": token.decimals,
            ]
            realm.create(TokenObject.self, value: update, update: true)
        }
        try! realm.commitWrite()
    }

    func fetch() {
        updatePrices()
        refreshBalance()
    }

    func getContractName(for addressString: String,
                         completion: @escaping (ResultResult<String, AnyError>.t) -> Void) {
        let address = Address(string: addressString)
        getNameCoordinator.getName(for: address!) { (result) in
            completion(result)
        }
    }

    func getContractSymbol(for addressString: String,
                           completion: @escaping (ResultResult<String, AnyError>.t) -> Void) {
        let address = Address(string: addressString)
        getSymbolCoordinator.getSymbol(for: address!) { result in
            completion(result)
        }
    }

    func getDecimals(for addressString: String,
                     completion: @escaping (ResultResult<UInt8, AnyError>.t) -> Void) {
        let address = Address(string: addressString)
        getDecimalsCoordinator.getDecimals(for: address!) { result in
            completion(result)
        }
    }

    func getContractName(for addressString: String) -> Promise<String> {
        let address = Address(string: addressString)
        return Promise { seal in
            getNameCoordinator.getName(for: address!) { (result) in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getContractSymbol(for addressString: String) -> Promise<String> {
        let address = Address(string: addressString)
        return Promise { seal in
            getSymbolCoordinator.getSymbol(for: address!) { result in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getDecimals(for addressString: String) -> Promise<UInt8> {
        let address = Address(string: addressString)
        return Promise { seal in
            getDecimalsCoordinator.getDecimals(for: address!) { result in
                switch result {
                case .success(let name):
                    seal.fulfill(name)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }

    func getTokenType(for addressString: String) -> Promise<TokenType> {
        return Promise { seal in
            getTokenType(for: addressString) { tokenType in
                seal.fulfill(tokenType)
            }
        }
    }


    func getERC875Balance(for addressString: String,
                          completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        let address = Address(string: addressString)
        getERC875BalanceCoordinator.getERC875TokenBalance(for: account.address, contract: address!) { result in
            completion(result)
        }
    }

    func getIsERC875Contract(for addressString: String,
                             completion: @escaping (ResultResult<Bool, AnyError>.t) -> Void) {
        let address = Address(string: addressString)
        getIsERC875ContractCoordinator.getIsERC875Contract(for: address!) { result in
            completion(result)
        }
    }

    func getERC721Balance(for addressString: String, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        let address = Address(string: addressString)
        getERC721BalanceCoordinator.getERC721TokenBalance(for: account.address, contract: address!) { result in
            switch result {
            case .success(let balance):
                completion(.success([String](repeating: "0", count: Int(balance))))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func getTokensFromOpenSea() -> OpenSea.PromiseResult {
        //TODO when we no longer create multiple instances of TokensDataStore, we don't have to use singleton for OpenSea class. This was to avoid fetching multiple times from OpenSea concurrently
        return OpenSea.sharedInstance.makeFetchPromise(config: config, owner: account.address.eip55String)
    }

    func getTokenType(for addressString: String,
                      completion: @escaping (TokenType) -> Void) {
        let address = Address(string: addressString)
        var knownToBeNotERC721 = false
        var knownToBeNotERC875 = false
        getIsERC875ContractCoordinator.getIsERC875Contract(for: address!) { [weak self] result in
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

        getIsERC721ContractCoordinator.getIsERC721Contract(for: address!) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case .success(let isERC721):
                if isERC721 {
                    completion(.erc721)
                    return
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

    func token(forContract contract: String) -> TokenObject? {
        return realm.objects(TokenObject.self).first { $0.contract.sameContract(as: contract) }
    }

    func refreshBalance() {
        updateDelegate()
        guard !enabledObject.isEmpty else {
            return
        }
        let etherToken = TokensDataStore.etherToken(for: config)
        let updateTokens = enabledObject.filter { $0 != etherToken }
        let nonERC721Tokens = updateTokens.filter { !$0.isERC721 }
        let erc721Tokens = updateTokens.filter { $0.isERC721 }
        refreshBalanceForNonERC721Tokens(tokens: nonERC721Tokens)
        refreshBalanceForERC721Tokens(tokens: erc721Tokens)
    }

    private func refreshBalanceForNonERC721Tokens(tokens: [TokenObject]) {
        assert(!tokens.contains { $0.isERC721 })
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
                guard let contract = Address(string: tokenObject.contract) else {
                    incrementCountAndUpdateDelegate()
                    return
                }
                getBalanceCoordinator.getBalance(for: account.address, contract: contract) { [weak self] result in
                    defer { incrementCountAndUpdateDelegate() }
                    guard let strongSelf = self else { return }
                    switch result {
                    case .success(let balance):
                        strongSelf.update(token: tokenObject, action: .value(balance))
                    case .failure:
                        break
                    }
                }
            case .erc875:
                getERC875Balance(for: tokenObject.contract, completion: { [weak self] result in
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
                //We'll check with OpenSea below and an ERC721 token isn't found there, then we get the balance of each token ourselves
                incrementCountAndUpdateDelegate()
            }
        }
    }

    private func refreshBalanceForERC721Tokens(tokens: [TokenObject]) {
        assert(!tokens.contains { !$0.isERC721 })
        getTokensFromOpenSea().done { [weak self] contractToOpenSeaNonFungibles in
            guard let strongSelf = self else { return }
            let erc721ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0.lowercased() }
            let erc721ContractsNotFoundInOpenSea = tokens.map { $0.contract.lowercased() } - erc721ContractsFoundInOpenSea
            var count = 0
            for each in erc721ContractsNotFoundInOpenSea {
                strongSelf.getERC721Balance(for: each) { [weak self] result in
                    guard let strongSelf = self else { return }
                    defer {
                        count += 1
                        if count == erc721ContractsNotFoundInOpenSea.count {
                            strongSelf.updateDelegate()
                        }
                    }
                    switch result {
                    case .success(let balance):
                        if let token = tokens.first(where: { $0.contract.sameContract(as: each) }) {
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

                if let tokenObject = tokens.first(where: { $0.contract.sameContract(as: contract) }) {
                    switch tokenObject.type {
                    case .nativeCryptocurrency, .erc721, .erc875:
                        break
                    case .erc20:
                        strongSelf.update(token: tokenObject, action: .type(.erc721))
                    }
                    strongSelf.update(token: tokenObject, action: .nonFungibleBalance(listOfJson))
                    if let anyNonFungible = anyNonFungible {
                        strongSelf.update(token: tokenObject, action: .name(anyNonFungible.contractName))
                    }
                } else {
                    if let address = Address(string: contract) {
                        let token = ERCToken(
                                contract: address,
                                name: openSeaNonFungibles[0].contractName,
                                symbol: openSeaNonFungibles[0].symbol,
                                decimals: 0,
                                type: .erc721,
                                balance: listOfJson
                        )
                        strongSelf.addCustom(token: token)
                    } else {
                        NSLog("Failed to add token from OpenSea: \(contract)")
                    }
                }
            }
            strongSelf.updateDelegate()
        }.catch {
            NSLog("Failed to retrieve tokens from OpenSea: \($0)")
        }
    }

    func refreshETHBalance() {
        getBalanceCoordinator.getEthBalance(for: account.address) {  [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let balance):
                let etherToken = TokensDataStore.etherToken(for: strongSelf.config)
                strongSelf.update(token: strongSelf.objects.first (where: { $0.contract.sameContract(as: etherToken.contract) })!, action: .value(balance.value))
                strongSelf.updateDelegate()
            case .failure: break
            }
        }
    }

    private func updateDelegate() {
        tokensModel.value = enabledObject
        let tokensViewModel = TokensViewModel(config: config, tokens: enabledObject, tickers: tickers)
        delegate?.didUpdate(result: .success( tokensViewModel ))
    }

    func coinTicker(for token: TokenObject) -> CoinTicker? {
        return tickers?[token.contract]
    }

    func addCustom(token: ERCToken) {
        let newToken = TokenObject(
            contract: token.contract.description,
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
        provider.request(priceToUpdate) { [weak self] result in
            guard let strongSelf = self else { return }
            guard case .success(let response) = result else { return }
            do {
                let tickers = try response.map([CoinTicker].self, using: JSONDecoder())
                strongSelf.tickers = tickers.reduce([String: CoinTicker]()) { (dict, ticker) -> [String: CoinTicker] in
                    var dict = dict
                    dict[ticker.contract] = ticker
                    return dict
                }
                strongSelf.updateDelegate()
            } catch { }
        }
    }

    private func getPriceToUpdate() -> AlphaWalletService? {
        switch config.server {
        case .main:
            return .priceOfEth(config: config)
        case .xDai:
            return .priceOfDai(config: config)
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .custom:
            return nil
        }
    }

    func add(deadContracts: [DeletedContract]) {
        try! realm.write {
            realm.add(deadContracts, update: false)
        }
    }

    func add(delegateContracts: [DelegateContract]) {
        try! realm.write {
            realm.add(delegateContracts, update: false)
        }
    }

    func add(hiddenContracts: [HiddenContract]) {
        try! realm.write {
            realm.add(hiddenContracts, update: false)
        }
    }

    @discardableResult
    func add(tokens: [TokenObject]) -> [TokenObject] {
        realm.beginWrite()
        realm.add(tokens, update: true)
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
    }

    func update(token: TokenObject, action: TokenUpdateAction) {
        guard !token.isInvalidated else { return }
        try! realm.write {
            switch action {
            case .value(let value):
                token.value = value.description
            case .isDisabled(let value):
                token.isDisabled = value
            case .nonFungibleBalance(let balance):
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
                realm.delete(token.balance)
                token.balance.append(objectsIn: newBalance)
            case .name(let name):
                token.name = name
            case .type(let type):
                token.type = type
            }
        }
    }

    enum TokenBalanceUpdateAction {
        case updateJsonProperty(String, Any)
    }

    ///Note that it's possible for a contract to have the same tokenId repeated
    func update(contract: String, tokenId: String, action: TokenBalanceUpdateAction) {
        guard let token = objects.first(where: { $0.contract.sameContract(as: contract) }) else { return }
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

    func jsonAttributeValue(forContract contract: String, tokenId: String, attributeName: String) -> Any? {
        guard let token = objects.first(where: { $0.contract.sameContract(as: contract) }) else { return nil }
        let tokenIdInt = BigUInt(tokenId.drop0x, radix: 16)
        guard let balance = token.balance.first(where: { BigUInt($0.balance.drop0x, radix: 16) == tokenIdInt }) else { return nil }
        let json = balance.json
        if let data = json.data(using: .utf8), var dictionary = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) {
            return dictionary[attributeName]
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

    func fetchTokenNamesForNonFungibleTokensIfEmpty() {
        assetDefinitionStore.forEachContractWithXML { [weak self] contract in
            guard let strongSelf = self else { return }
            let localizedName = XMLHandler(contract: contract).getName()
            if localizedName != "N/A" {
                if let storedToken = strongSelf.enabledObject.first(where: { $0.contract.sameContract(as: contract) }), storedToken.name.isEmpty {
                    getContractName(for: contract) { result in
                        switch result {
                        case .success(let name):
                            //TODO multiple realm writes in a loop. Should we group them together?
                            strongSelf.updateTokenName(token: storedToken, to: name)
                        case .failure:
                            break
                        }
                    }
                }
            }
        }
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
