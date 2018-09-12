// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import Result
import APIKit
import RealmSwift
import BigInt
import Moya
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

    private lazy var claimOrderCoordinator: ClaimOrderCoordinator = {
        return ClaimOrderCoordinator(web3: web3)
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

    private let provider = TrustProviderFactory.makeProvider()

    let account: Wallet
    let config: Config
    let web3: Web3Swift
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: TokensDataStoreDelegate?
    let realm: Realm
    var tickers: [String: CoinTicker]? = .none
    var pricesTimer = Timer()
    var ethTimer = Timer()
    //We should refresh prices every 5 minutes.
    let intervalToRefreshPrices = 300.0
    //We should refresh balance of the ETH every 10 seconds.
    let intervalToETHRefresh = 10.0
    var tokensModel: Subscribable<[TokenObject]> = Subscribable(nil)

    static func etherToken(for config: Config) -> TokenObject {
        return TokenObject(
            contract: Constants.nullAddress,
            name: config.server.name,
            symbol: config.server.symbol,
            decimals: config.server.decimals,
            value: "0",
            isCustom: false,
            type: .ether
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
                type: .ether
        )
    }

    init(
            realm: Realm,
            account: Wallet,
            config: Config,
            web3: Web3Swift,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.account = account
        self.config = config
        self.web3 = web3
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

    func getERC721Balance(for addressString: String,
                          completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        let tokenType = CryptoKittyHandling(contract: addressString)
        switch tokenType {
        case .cryptoKitty:
            getCryptoKittyBalance(for: addressString, completion: completion)
        case .otherNonFungibleToken:
            getGenericERC721Balance(for: addressString, completion: completion)
        }
    }

    private func getGenericERC721Balance(for addressString: String,
                                         completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        let address = Address(string: addressString)
        getERC721BalanceCoordinator.getERC721TokenBalance(for: account.address, contract: address!) { result in
            switch result {
            case .success(let ints):
                completion(.success(ints.map {
                    MarketQueueHandler.bytesToHexa($0.data.array)
                }))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func getCryptoKittyBalance(for addressString: String,
                                         completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        guard let url = URL(string: "\(Constants.openseaAPI)api/v1/assets/?owner=\(account.address.eip55String)&order_by=current_price&order_direction=asc") else {
            completion(.failure(AnyError(CryptoKittyError(localizedDescription: "Error calling \(Constants.openseaAPI) API"))))
            return
        }
        Alamofire.request(
                url,
                method: .get
        ).responseJSON { response in
            guard let data = response.data, let json = try? JSON(data: data) else {
                completion(.failure(AnyError(CryptoKittyError(localizedDescription: "Error calling \(Constants.openseaAPI) API"))))
                return
            }
            var results = [String]()
            for (_, each): (String, JSON) in json["assets"] where each["asset_contract"]["address"].stringValue.sameContract(as: Constants.cryptoKittiesContractAddress) {
                let tokenId = each["token_id"].stringValue
                let description = each["description"].stringValue
                let thumbnailUrl = each["image_thumbnail_url"].stringValue
                let imageUrl = each["image_url"].stringValue
                let externalLink = each["external_link"].stringValue
                var traits = [CryptoKittyTrait]()
                for each in each["traits"].arrayValue {
                    let traitCount = each["trait_count"].intValue
                    let traitType = each["trait_type"].stringValue
                    let traitValue = each["value"].stringValue
                    let trait = CryptoKittyTrait(count: traitCount, type: traitType, value: traitValue)
                    traits.append(trait)
                }
                let cat = CryptoKitty(tokenId: tokenId, description: description, thumbnailUrl: thumbnailUrl, imageUrl: imageUrl, externalLink: externalLink, traits: traits)
                if let encodedJson = try? JSONEncoder().encode(cat), let jsonString = String(data: encodedJson, encoding: .utf8) {
                    results.append(jsonString)
                } else {
                    completion(.failure(AnyError(CryptoKittyError(localizedDescription: "Error converting JSON to CryptoKitty"))))
                    return
                }
            }
            completion(.success(results))
        }
    }

    func getTokenType(for addressString: String,
                      completion: @escaping (TokenType) -> Void) {
        let address = Address(string: addressString)
        getIsERC875ContractCoordinator.getIsERC875Contract(for: address!) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let isERC875):
                if isERC875 {
                    completion(.erc875)
                } else {
                    strongSelf.getIsERC721ContractCoordinator.getIsERC721Contract(for: address!) { result in
                        switch result {
                        case .success(let isERC721):
                            if isERC721 {
                                completion(.erc721)
                            } else {
                                completion(.erc20)
                            }
                        case .failure:
                            completion(.erc20)
                        }
                    }
                }
            case .failure:
                strongSelf.getIsERC721ContractCoordinator.getIsERC721Contract(for: address!) { result in
                    switch result {
                    case .success(let isERC721):
                        if isERC721 {
                            completion(.erc721)
                        } else {
                            completion(.erc20)
                        }
                    case .failure:
                        completion(.erc20)
                    }
                }
            }
        }
    }

    //Result<Void, AnyError>
    //claim order continues to use indices to do the transaction, not the bytes32 variables
    func claimOrder(tokenIndices: [UInt16],
                    expiry: BigUInt,
                    v: UInt8,
                    r: String,
                    s: String,
                    completion: @escaping(Any) -> Void) {
        claimOrderCoordinator.claimOrder(indices: tokenIndices, expiry: expiry, v: v, r: r, s: s) { result in
            completion(result)
        }
    }

    func refreshBalance() {
        updateDelegate()
        guard !enabledObject.isEmpty else {
            return
        }
        let etherToken = TokensDataStore.etherToken(for: config)
        let updateTokens = enabledObject.filter { $0 != etherToken }
        var count = 0
        for tokenObject in updateTokens {
            switch tokenObject.type {
            case .ether:
                break
            case .erc20:
                guard let contract = Address(string: tokenObject.contract) else { return }
                getBalanceCoordinator.getBalance(for: account.address, contract: contract) { [weak self] result in
                    guard let strongSelf = self else { return }
                    switch result {
                    case .success(let balance):
                        strongSelf.update(token: tokenObject, action: .value(balance))
                    case .failure: break
                    }
                    count += 1
                    if count == updateTokens.count {
                        strongSelf.refreshETHBalance()
                    }
                }
            case .erc875:
                getERC875Balance(for: tokenObject.contract, completion: { [weak self] result in
                    guard let strongSelf = self else { return }
                    switch result {
                    case .success(let balance):
                        strongSelf.update(token: tokenObject, action: .nonFungibleBalance(balance))
                    case .failure: break
                    }

                })
            case .erc721:
                getERC721Balance(for: tokenObject.contract, completion: { [weak self] result in
                    guard let strongSelf = self else { return }
                    switch result {
                    case .success(let balance):
                        strongSelf.update(token: tokenObject, action: .nonFungibleBalance(balance))
                    case .failure: break
                    }

                })
            }
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
    func updateDelegate() {
        tokensModel.value = enabledObject
        let tokensViewModel = TokensViewModel(config: config, tokens: enabledObject, tickers: tickers)
        delegate?.didUpdate(result: .success( tokensViewModel ))
    }

    func coinTicker(for token: TokenObject) -> CoinTicker? {
        return tickers?[token.contract]
    }

    func handleError(error: Error) {
        delegate?.didUpdate(result: .failure(TokenError.failedToFetch))
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
//        let tokens = objects.map { TokenPrice(contract: $0.contract, symbol: $0.symbol) }
//        let tokensPrice = TokensPrice(
//            currency: config.currency.rawValue,
//            tokens: tokens
//        )
        provider.request(.prices) { [weak self] result in
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

    func deleteAll() {
        try! realm.write {
            realm.delete(realm.objects(TokenObject.self))
        }
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
                token.balance.removeAll()
                if !balance.isEmpty {
                    for i in 0...balance.count - 1 {
                        token.balance.append(TokenBalance(balance: balance[i]))
                    }
                }
            }
        }
    }

    private func scheduledTimerForPricesUpdate() {
        guard !config.isAutoFetchingDisabled else { return }
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

    public func fetchTokenNamesForNonFungibleTokensIfEmpty() {
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
