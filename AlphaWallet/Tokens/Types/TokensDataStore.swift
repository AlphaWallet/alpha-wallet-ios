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

protocol TokensDataStorePriceDelegate: class {
    func updatePrice(forTokenDataStore tokensDataStore: TokensDataStore)
}

// swiftlint:disable type_body_length
class TokensDataStore {
    typealias ContractAndJson = (contract: AlphaWallet.Address, json: String)

    static let fetchContractDataTimeout = TimeInterval(4)

    //Unlike `SessionManager.default`, this doesn't add default HTTP headers. It looks like POAP token URLs (e.g. https://api.poap.xyz/metadata/2503/278569) don't like them and return `406` in the JSON. It's strangely not responsible when curling, but only when running in the app
    private var sessionManagerWithDefaultHttpHeaders: SessionManager = {
        let configuration = URLSessionConfiguration.default
        return SessionManager(configuration: configuration)
    }()

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

    private let filterTokensCoordinator: FilterTokensCoordinator
    private let account: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private let realm: Realm
    private var pricesTimer = Timer()
    private var ethTimer = Timer()
    //We should refresh prices every 5 minutes.
    private let intervalToRefreshPrices = 300.0
    private let intervalToETHRefresh = 10.0
    private let numberOfTimesToRetryFetchContractData = 2

    private var chainId: Int {
        return server.chainID
    }
    private var isFetchingPrices = false
    private let config: Config
    private let openSea: OpenSea
    private let queue = DispatchQueue.global()

    let server: RPCServer
    weak var delegate: TokensDataStoreDelegate?
    weak var priceDelegate: TokensDataStorePriceDelegate?
    weak var erc721TokenIdsFetcher: Erc721TokenIdsFetcher?
    //TODO why is this a dictionary? There seems to be only at most 1 key-value pair in the dictionary
    var tickers: [AddressAndRPCServer: CoinTicker] = .init() {
        didSet {
            if oldValue == tickers {
                //no-op
            } else {
                updateDelegate()
            }
        }
    }
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
        return Array(realm.threadSafe.objects(TokenObject.self)
                .filter("chainId = \(self.chainId)")
                .filter("isDisabled = false"))
    }

    var deletedContracts: [DeletedContract] {
        return Array(realm.threadSafe.objects(DeletedContract.self)
                .filter("chainId = \(self.chainId)"))
    }

    var delegateContracts: [DelegateContract] {
        return Array(realm.threadSafe.objects(DelegateContract.self)
                .filter("chainId = \(self.chainId)"))
    }

    var hiddenContracts: [HiddenContract] {
        return Array(realm.threadSafe.objects(HiddenContract.self)
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
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getNameCoordinator.getName(for: address) { (result) in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getContractSymbol(for address: AlphaWallet.Address,
                           completion: @escaping (ResultResult<String, AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getSymbolCoordinator.getSymbol(for: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getDecimals(for address: AlphaWallet.Address,
                     completion: @escaping (ResultResult<UInt8, AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getDecimalsCoordinator.getDecimals(for: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getContractName(for address: AlphaWallet.Address) -> Promise<String> {
        Promise { seal in
            getContractName(for: address) { (result) in
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
        Promise { seal in
            getContractSymbol(for: address) { result in
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
        Promise { seal in
            getDecimals(for: address) { result in
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
        Promise { seal in
            getTokenType(for: address) { tokenType in
                seal.fulfill(tokenType)
            }
        }
    }

    func getERC20Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<BigInt, AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC20BalanceCoordinator.getBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getERC875Balance(for address: AlphaWallet.Address,
                          completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC875BalanceCoordinator.getERC875TokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    func getERC721ForTicketsBalance(for address: AlphaWallet.Address,
                                    completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC721ForTicketsBalanceCoordinator.getERC721ForTicketsTokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success:
                    completion(result)
                case .failure:
                    if !triggerRetry() {
                        completion(result)
                    }
                }
            }
        }
    }

    //TODO should callers call tokenURI and so on, instead?
    func getERC721Balance(for address: AlphaWallet.Address, completion: @escaping (ResultResult<[String], AnyError>.t) -> Void) {
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getERC721BalanceCoordinator.getERC721TokenBalance(for: strongSelf.account.address, contract: address) { result in
                switch result {
                case .success(let balance):
                    if balance >= Int.max {
                        completion(.failure(AnyError(Web3Error(description: ""))))
                    } else {
                        completion(.success([String](repeating: "0", count: Int(balance))))
                    }
                case .failure(let error):
                    if !triggerRetry() {
                        completion(.failure(error))
                    }
                }
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
        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            //Function hash is "0x4f452b9a". This might cause many "execution reverted" RPC errors
            //TODO rewrite flow so we reduce checks for this as it causes too many "execution reverted" RPC errors and looks scary when we look in Charles proxy. Maybe check for ERC20 (via EIP165) as well as ERC721 in parallel first, then fallback to this ERC875 check
            strongSelf.getIsERC875ContractCoordinator.getIsERC875Contract(for: address) { [weak self] result in
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
                    if !triggerRetry() {
                        knownToBeNotERC875 = true
                    }
                }
                if knownToBeNotERC721 && knownToBeNotERC875 {
                    completion(.erc20)
                }
            }
        }

        withRetry(times: numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry in
            guard let strongSelf = self else { return }
            strongSelf.getIsERC721ContractCoordinator.getIsERC721Contract(for: address) { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success(let isERC721):
                    if isERC721 {
                        withRetry(times: strongSelf.numberOfTimesToRetryFetchContractData) { [weak self] triggerRetry2 in
                            guard let strongSelf = self else { return }
                            strongSelf.getIsERC721ForTicketsContractCoordinator.getIsERC721ForTicketContract(for: address) { result in
                                switch result {
                                case .success(let isERC721ForTickets):
                                    if isERC721ForTickets {
                                        completion(.erc721ForTickets)
                                    } else {
                                        completion(.erc721)
                                    }
                                case .failure:
                                    if !triggerRetry2() {
                                        completion(.erc721)
                                    }
                                }
                            }
                        }
                    } else {
                        knownToBeNotERC721 = true
                    }
                case .failure:
                    if !triggerRetry() {
                        knownToBeNotERC721 = true
                    }
                }
                if knownToBeNotERC721 && knownToBeNotERC875 {
                    completion(.erc20)
                }
            }
        }
    }

    func tokenThreadSafe(forContract contract: AlphaWallet.Address) -> TokenObject? {
        realm.threadSafe.objects(TokenObject.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("chainId = \(chainId)").first
    }

    func token(forContract contract: AlphaWallet.Address) -> TokenObject? {
        realm.objects(TokenObject.self)
                .filter("contract = '\(contract.eip55String)'")
                .filter("chainId = \(chainId)").first
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
            refreshBalance(forToken: tokenObject, completion: incrementCountAndUpdateDelegate)
        }
    }

    private func refreshBalance(forToken tokenObject: TokenObject, completion: @escaping () -> Void) {
        switch tokenObject.type {
        case .nativeCryptocurrency:
            completion()
        case .erc20:
            getERC20Balance(for: tokenObject.contractAddress, completion: { [weak self] result in
                defer { completion() }
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
                defer { completion() }
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
                defer { completion() }
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

    private func refreshBalanceForERC721Tokens(tokens: [TokenObject]) {
        assert(!tokens.contains { !$0.isERC721AndNotForTickets })
        firstly {
            getTokensFromOpenSea()
        }.done { [weak self] contractToOpenSeaNonFungibles in
            guard let strongSelf = self else { return }
            let erc721ContractsFoundInOpenSea = Array(contractToOpenSeaNonFungibles.keys).map { $0 }
            let erc721ContractsNotFoundInOpenSea = tokens.map { $0.contractAddress } - erc721ContractsFoundInOpenSea
            strongSelf.updateNonOpenSeaNonFungiblesBalance(erc721ContractsNotFoundInOpenSea: erc721ContractsNotFoundInOpenSea, tokens: tokens)
            strongSelf.updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: contractToOpenSeaNonFungibles, tokens: tokens)
            strongSelf.updateDelegate()
        }.cauterize()
    }

    private func updateNonOpenSeaNonFungiblesBalance(erc721ContractsNotFoundInOpenSea contracts: [AlphaWallet.Address], tokens: [TokenObject]) {
        let promises = contracts.map { updateNonOpenSeaNonFungiblesBalance(contract: $0, tokens: tokens) }
        firstly {
            when(resolved: promises)
        }.done { _ in
            self.updateDelegate()
        }
    }

    private func updateNonOpenSeaNonFungiblesBalance(contract: AlphaWallet.Address, tokens: [TokenObject]) -> Promise<Void> {
        guard let erc721TokenIdsFetcher = erc721TokenIdsFetcher else { return Promise { _ in } }
        return firstly {
            erc721TokenIdsFetcher.tokenIdsForErc721Token(contract: contract, inAccount: account.address)
        }.then {  tokenIds -> Promise<[ContractAndJson]> in
            let guarantees: [Guarantee<ContractAndJson>] = tokenIds.map { self.fetchNonFungibleJson(forTokenId: $0, address: contract, tokens: tokens) }
            return when(fulfilled: guarantees)
        }.done { listOfContractAndJsonResult in
            var contractsAndJsons: [AlphaWallet.Address: [String]] = .init()
            for each in listOfContractAndJsonResult {
                if var listOfJson = contractsAndJsons[each.contract] {
                    listOfJson.append(each.json)
                    contractsAndJsons[each.contract] = listOfJson
                } else {
                    contractsAndJsons[each.contract] = [each.json]
                }
            }
            for (contract, jsons) in contractsAndJsons {
                guard let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) else { continue }
                self.update(token: tokenObject, action: .nonFungibleBalance(jsons))
            }
        }.asVoid()
    }

    private func fetchNonFungibleJson(forTokenId tokenId: String, address: AlphaWallet.Address, tokens: [TokenObject]) -> Guarantee<ContractAndJson> {
        return firstly {
            Erc721Contract(server: server).getErc721TokenUri(for: tokenId, contract: address)
        }.then {
            self.fetchTokenJson(forTokenId: tokenId, uri: $0, address: address, tokens: tokens)
        }.recover { _ in
            var jsonDictionary = JSON()
            if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
                jsonDictionary["tokenId"] = JSON(tokenId)
                jsonDictionary["contractName"] = JSON(tokenObject.name)
                jsonDictionary["symbol"] = JSON(tokenObject.symbol)
                jsonDictionary["name"] = ""
                jsonDictionary["imageUrl"] = ""
                jsonDictionary["thumbnailUrl"] = ""
                jsonDictionary["externalLink"] = ""
            }
            return .value((contract: address, json: jsonDictionary.rawString()!))
        }
    }

    private func fetchTokenJson(forTokenId tokenId: String, uri originalUri: URL, address: AlphaWallet.Address, tokens: [TokenObject]) -> Promise<ContractAndJson> {
        struct Error: Swift.Error {
        }
        let uri = originalUri.rewrittenIfIpfs
        return firstly {
            //Must not use `SessionManager.default.request` or `Alamofire.request` which uses the former. See comment in var
            sessionManagerWithDefaultHttpHeaders.request(uri, method: .get).responseData()
        }.map { data, _ in
            if let json = try? JSON(data: data) {
                if json["error"] == "Internal Server Error" {
                    throw Error()
                } else {
                    var jsonDictionary = json
                    if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: address) }) {
                        //We must make sure the value stored is at least an empty string, never nil because we need to deserialise/decode it
                        jsonDictionary["tokenId"] = JSON(tokenId)
                        jsonDictionary["contractName"] = JSON(tokenObject.name)
                        jsonDictionary["symbol"] = JSON(tokenObject.symbol)
                        jsonDictionary["name"] = JSON(jsonDictionary["name"].stringValue)
                        jsonDictionary["imageUrl"] = JSON(jsonDictionary["image"].string ?? jsonDictionary["image_url"].string ?? "")
                        jsonDictionary["thumbnailUrl"] = jsonDictionary["imageUrl"]
                        //POAP tokens (https://blockscout.com/xdai/mainnet/address/0x22C1f6050E56d2876009903609a2cC3fEf83B415/transactions), eg. https://api.poap.xyz/metadata/2503/278569, use `home_url` as the key for what they should use `external_url` for and they use `external_url` to point back to the token URI
                        jsonDictionary["externalLink"] = JSON(jsonDictionary["home_url"].string ?? jsonDictionary["external_url"].string ?? "")
                    }
                    if let jsonString = jsonDictionary.rawString() {
                        return (contract: address, json: jsonString)
                    } else {
                        throw Error()
                    }
                }
            } else {
                throw Error()
            }
        }
    }

    private func updateOpenSeaNonFungiblesBalanceAndAttributes(contractToOpenSeaNonFungibles: [AlphaWallet.Address: [OpenSeaNonFungible]], tokens: [TokenObject]) {
        for (contract, openSeaNonFungibles) in contractToOpenSeaNonFungibles {
            var listOfJson = [String]()
            var anyNonFungible: OpenSeaNonFungible?
            for each in openSeaNonFungibles {
                if let encodedJson = try? JSONEncoder().encode(each), let jsonString = String(data: encodedJson, encoding: .utf8) {
                    anyNonFungible = each
                    listOfJson.append(jsonString)
                } else {
                    //no op
                }
            }

            if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) {
                switch tokenObject.type {
                case .nativeCryptocurrency, .erc721, .erc875, .erc721ForTickets:
                    break
                case .erc20:
                    update(token: tokenObject, action: .type(.erc721))
                }
                update(token: tokenObject, action: .nonFungibleBalance(listOfJson))
                if let anyNonFungible = anyNonFungible {
                    update(token: tokenObject, action: .name(anyNonFungible.contractName))
                }
            } else {
                let token = ERCToken(
                        contract: contract,
                        server: server,
                        name: openSeaNonFungibles[0].contractName,
                        symbol: openSeaNonFungibles[0].symbol,
                        decimals: 0,
                        type: .erc721,
                        balance: listOfJson
                )

                addCustom(token: token)
            }
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

        let tokensViewModel = TokensViewModel(filterTokensCoordinator: filterTokensCoordinator, tokens: enabledObject, tickers: tickers)
        delegate?.didUpdate(result: .success(tokensViewModel), refreshImmediately: refreshImmediately)
    }

    func coinTicker(for token: TokenObject) -> CoinTicker? {
        return tickers[token.addressAndRPCServer]
    }

    @discardableResult func addCustom(token: ERCToken) -> TokenObject {
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

        return newToken
    }

    func updatePricesAfterComingOnline() {
        updatePrices()
    }

    func updatePrices() {
        priceDelegate?.updatePrice(forTokenDataStore: self)
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
            queue.async {
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
        if let data = json.data(using: .utf8), let dictionary = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) {
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

extension Realm {
    var threadSafe: Realm {
         try! Realm(configuration: self.configuration)
    }
}

extension TokenObject {
    var addressAndRPCServer: AddressAndRPCServer {
        return .init(address: contractAddress, server: server)
    }
}
