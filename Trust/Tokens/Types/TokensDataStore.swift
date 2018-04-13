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

    private lazy var getStormBirdBalanceCoordinator: GetStormBirdBalanceCoordinator = {
        return GetStormBirdBalanceCoordinator(web3: self.web3)
    }()

    private lazy var getIsStormBirdCoordinator: GetIsStormBirdCoordinator = {
        return GetIsStormBirdCoordinator(web3: self.web3)
    }()

    private lazy var getDecimalsCoordinator: GetDecimalsCoordinator = {
        return GetDecimalsCoordinator(web3: self.web3)
    }()

    private let provider = TrustProviderFactory.makeProvider()

    let account: Wallet
    let config: Config
    let web3: Web3Swift
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
            isCustom: false
        )
    }

    init(
        realm: Realm,
        account: Wallet,
        config: Config,
        web3: Web3Swift
    ) {
        self.account = account
        self.config = config
        self.web3 = web3
        self.realm = realm
        self.addEthToken()
        self.scheduledTimerForPricesUpdate()
        self.scheduledTimerForEthBalanceUpdate()
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

    func getStormBirdBalance(for addressString: String,
                             completion: @escaping (Result<BigUInt, AnyError>) -> Void) {
        let address = Address(string: addressString)
        getStormBirdBalanceCoordinator.getBalance(for: account.address, contract: address!) { result in
            var balance = 0
            for i in try! 0...result.dematerialize().count - 1 {
                if(BigUInt(try! result.dematerialize()[i], radix: 16)! > 0) {
                    balance += 1
                }
            }
            completion(.success(BigUInt(balance)))
        }
    }

    func getIsStormBird(for addressString: String,
                        completion: @escaping (Result<Bool, AnyError>) -> Void) {
        let address = Address(string: addressString)
        getIsStormBirdCoordinator.getIsStormBirdContract(for: address!) { result in
            completion(result)
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
        guard !enabledObject.isEmpty else {
            updateDelegate()
            return
        }
        let etherToken = TokensDataStore.etherToken(for: config)
        let updateTokens = enabledObject.filter { $0 != etherToken }
        var count = 0
        for tokenObject in updateTokens {
            if tokenObject.isStormBird {
                //getStormBirdBalance(for: tokenObject.contract, completion: { result in
                let contractAddress = Address(eip55: tokenObject.contract)!
                getStormBirdBalanceCoordinator.getBalance(for: tokenObject.address, contract: contractAddress) { result in
                    switch result {
                    case .success(let balance):
                        guard !balance.isEmpty else {
                            return
                        }
                        var indices = [UInt16]()
                        for i in 0...balance.count - 1 {
                            if(BigUInt(balance[i], radix: 16)! > 0){
                                indices.append(UInt16(i))
                            }
                        }
                        self.update(token: tokenObject, action: .stormBirdBalance(indices))
                    case .failure: break
                    }
                
                }
            } else {
                guard let contract = Address(string: tokenObject.contract) else { return }
                getBalanceCoordinator.getBalance(for: account.address, contract: contract) { [weak self] result in
                    guard let `self` = self else { return }
                    switch result {
                    case .success(let balance):
                        guard !balance.isEmpty else {
                            return
                        }
                        var indices = [UInt16]()
                        for i in 0...balance.count - 1 {
                            if(BigUInt(balance[i], radix: 16)! > 0){
                                indices.append(UInt16(i))
                            }
                        }
                        //TODO make this consistant, either BigUInt or Int
                        self.update(token: tokenObject, action: .value(BigInt(indices.count)))
                    case .failure: break
                    }
                    count += 1
                    if count == updateTokens.count {
                        self.refreshETHBalance()
                    }
                }
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
        let tokensViewModel = TokensViewModel( tokens: enabledObject, tickers: tickers )
        delegate?.didUpdate(result: .success( tokensViewModel ))
    }

    func coinTicker(for token: TokenObject) -> CoinTicker? {
        return tickers?[token.contract]
    }

    func handleError(error: Error) {
        delegate?.didUpdate(result: .failure(TokenError.failedToFetch))
    }

    func addCustom(token: ERC20Token) {
        let newToken = TokenObject(
            contract: token.contract.description,
            name: token.name,
            symbol: token.symbol,
            decimals: token.decimals,
            value: "0",
            isCustom: true,
            isStormBird: token.isStormBird
        )
        token.balance.forEach { balance in
            newToken.balance.append(TokenBalance(balance: BigUInt(balance, radix: 16)!))
        }
        add(tokens: [newToken])
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

    enum TokenUpdate {
        case value(BigInt)
        case isDisabled(Bool)
        case stormBirdBalance([UInt16])
    }

    func update(token: TokenObject, action: TokenUpdate) {
        try! realm.write {
            switch action {
            case .value(let value):
                token.value = value.description
            case .isDisabled(let value):
                token.isDisabled = value
            case .stormBirdBalance(let balance):
                token.balance.removeAll()
                //token.balance.append(objectsIn: balance.map { TokenBalance(balance: Int16($0)) })
            }
        }
    }

    private func scheduledTimerForPricesUpdate() {
        pricesTimer = Timer.scheduledTimer(timeInterval: intervalToRefreshPrices, target: BlockOperation { [weak self] in
            self?.updatePrices()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }
    private func scheduledTimerForEthBalanceUpdate() {
        ethTimer = Timer.scheduledTimer(timeInterval: intervalToETHRefresh, target: BlockOperation { [weak self] in
            self?.refreshETHBalance()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }
    deinit {
        //We should make sure that timer is invalidate.
        pricesTimer.invalidate()
        ethTimer.invalidate()
    }
}
