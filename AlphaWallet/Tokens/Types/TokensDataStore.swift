// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result
import APIKit
import RealmSwift
import BigInt
import Moya
import TrustKeystore

enum TokenError: Error {
    case failedToFetch
}

protocol TokensDataStoreDelegate: class {
    func didUpdate(result: Result<TokensViewModel, TokenError>)
}

class TokensDataStore {

    private lazy var getBalanceCoordinator: GetBalanceCoordinator = {
        return GetBalanceCoordinator(web3: self.web3)
    }()

    private lazy var claimOrderCoordinator: ClaimOrderCoordinator = {
        return ClaimOrderCoordinator(web3: self.web3)
    }()

    private lazy var getNameCoordinator: GetNameCoordinator = {
        return GetNameCoordinator(web3: self.web3)
    }()

    private lazy var getSymbolCoordinator: GetSymbolCoordinator = {
        return GetSymbolCoordinator(web3: self.web3)
    }()

    private lazy var getERC875BalanceCoordinator: GetERC875BalanceCoordinator = {
        return GetERC875BalanceCoordinator(web3: self.web3)
    }()

    private lazy var getIsERC875ContractCoordinator: GetIsERC875ContractCoordinator = {
        return GetIsERC875ContractCoordinator(web3: self.web3)
    }()

    private lazy var getERC721BalanceCoordinator: GetERC721BalanceCoordinator = {
        return GetERC721BalanceCoordinator(web3: self.web3)
    }()

    private lazy var getIsERC721ContractCoordinator: GetIsERC721ContractCoordinator = {
        return GetIsERC721ContractCoordinator(web3: self.web3)
    }()

    private lazy var getDecimalsCoordinator: GetDecimalsCoordinator = {
        return GetDecimalsCoordinator(web3: self.web3)
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
            contract: "0x0000000000000000000000000000000000000000",
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

        updateERC875TokensToLocalizedName()
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

    var hiddenContracts: [HiddenContract] {
        return Array(realm.objects(HiddenContract.self))
    }

    static func update(in realm: Realm, tokens: [Token]) {
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
                         completion: @escaping (Result<String, AnyError>) -> Void) {
        let address = Address(string: addressString)
        getNameCoordinator.getName(for: address!) { (result) in
            completion(result)
        }
    }

    func getContractSymbol(for addressString: String,
                           completion: @escaping (Result<String, AnyError>) -> Void) {
        let address = Address(string: addressString)
        getSymbolCoordinator.getSymbol(for: address!) { result in
            completion(result)
        }
    }
    func getDecimals(for addressString: String,
                     completion: @escaping (Result<UInt8, AnyError>) -> Void) {
        let address = Address(string: addressString)
        getDecimalsCoordinator.getDecimals(for: address!) { result in
            completion(result)
        }
    }

    func getERC875Balance(for addressString: String,
                          completion: @escaping (Result<[String], AnyError>) -> Void) {
        let address = Address(string: addressString)
        getERC875BalanceCoordinator.getERC875TokenBalance(for: account.address, contract: address!) { result in
            completion(result)
        }
    }

    func getIsERC875Contract(for addressString: String,
                             completion: @escaping (Result<Bool, AnyError>) -> Void) {
        let address = Address(string: addressString)
        getIsERC875ContractCoordinator.getIsERC875Contract(for: address!) { result in
            completion(result)
        }
    }

    func getERC721Balance(for addressString: String,
                          completion: @escaping (Result<[String], AnyError>) -> Void) {
        let address = Address(string: addressString)
        getERC721BalanceCoordinator.getERC721TokenBalance(for: account.address, contract: address!) { result in
            switch result {
            case .success(let ints):
                completion(.success(ints.map { MarketQueueHandler.bytesToHexa($0.data.array) }))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getTokenType(for addressString: String,
                      completion: @escaping (TokenType) -> Void) {
        let address = Address(string: addressString)
        getIsERC875ContractCoordinator.getIsERC875Contract(for: address!) { result in
            switch result {
            case .success(let isERC875):
                if isERC875 {
                    completion(.erc875)
                } else {
                    self.getIsERC721ContractCoordinator.getIsERC721Contract(for: address!) { result in
                        switch result {
                        case .success(let isERC721):
                            if isERC721 {
                                completion(.erc721)
                            } else {
                                completion(.erc20)
                            }
                            break
                        case .failure:
                            completion(.erc20)
                            break
                        }
                    }
                }
                break
            case .failure:
                self.getIsERC721ContractCoordinator.getIsERC721Contract(for: address!) { result in
                    switch result {
                    case .success(let isERC721):
                        if isERC721 {
                            completion(.erc721)
                        } else {
                            completion(.erc20)
                        }
                        break
                    case .failure:
                        completion(.erc20)
                        break
                    }
                }
                break
            }
        }
    }

    //Result<Void, AnyError>
    //claim order continues to use indices to do the transaction, not the bytes32 variables
    func claimOrder(ticketIndices: [UInt16],
                    expiry: BigUInt,
                    v: UInt8,
                    r: String,
                    s: String,
                    completion: @escaping(Any) -> Void) {
        claimOrderCoordinator.claimOrder(indices: ticketIndices, expiry: expiry, v: v, r: r, s: s) { result in
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
                    guard let `self` = self else { return }
                    switch result {
                    case .success(let balance):
                        self.update(token: tokenObject, action: .value(balance))
                    case .failure: break
                    }
                    count += 1
                    if count == updateTokens.count {
                        self.refreshETHBalance()
                    }
                }
            case .erc875:
                getERC875Balance(for: tokenObject.contract, completion: { result in
                    switch result {
                    case .success(let balance):
                        self.update(token: tokenObject, action: .stormBirdBalance(balance))
                    case .failure: break
                    }

                })
            case .erc721:
                getERC721Balance(for: tokenObject.contract, completion: { result in
                    switch result {
                    case .success(let balance):
                        self.update(token: tokenObject, action: .stormBirdBalance(balance))
                    case .failure: break
                    }

                })
            }
        }
    }
    func refreshETHBalance() {
        self.getBalanceCoordinator.getEthBalance(for: self.account.address) {  [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .success(let balance):
                let etherToken = TokensDataStore.etherToken(for: self.config)
                self.update(token: self.objects.first (where: { $0.contract == etherToken.contract })!, action: .value(balance.value))
                self.updateDelegate()
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
        let tokens = objects.map { TokenPrice(contract: $0.contract, symbol: $0.symbol) }
        let tokensPrice = TokensPrice(
            currency: config.currency.rawValue,
            tokens: tokens
        )
        provider.request(.prices(tokensPrice)) { [weak self] result in
            guard let `self` = self else { return }
            guard case .success(let response) = result else { return }
            do {
                let tickers = try response.map([CoinTicker].self, atKeyPath: "response", using: JSONDecoder())
                self.tickers = tickers.reduce([String: CoinTicker]()) { (dict, ticker) -> [String: CoinTicker] in
                    var dict = dict
                    dict[ticker.contract] = ticker
                    return dict
                }
                self.updateDelegate()
            } catch { }
        }
    }

    func add(deadContracts: [DeletedContract]) {
        try! realm.write {
            realm.add(deadContracts, update: false)
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

    enum TokenUpdate {
        case value(BigInt)
        case isDisabled(Bool)
        case stormBirdBalance([String])
    }

    func update(token: TokenObject, action: TokenUpdate) {
        guard !token.isInvalidated else { return }
        try! realm.write {
            switch action {
            case .value(let value):
                token.value = value.description
            case .isDisabled(let value):
                token.isDisabled = value
            case .stormBirdBalance(let balance):
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

    public func updateERC875TokensToLocalizedName() {
        assetDefinitionStore.forEachContractWithXML { contract in
            if let token = config.createDefaultTicketToken(forContract: contract) {
                let contract = token.contract.eip55String
                let localizedName = token.name
                if let storedTicketToken = enabledObject.first(where: { $0.contract == contract }) {
                    //TODO multiple realm writes in a loop. Should we group them together?
                    updateTicketTokenName(token: storedTicketToken, to: localizedName)
                }
            }
        }
    }

    private func updateTicketTokenName(token: TokenObject, to name: String) {
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
