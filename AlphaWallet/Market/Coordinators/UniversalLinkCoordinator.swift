// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import BigInt
import PromiseKit
import RealmSwift
import web3swift

protocol UniversalLinkCoordinatorDelegate: class, CanOpenURL {
	func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController?
	func completed(in coordinator: UniversalLinkCoordinator)
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void)
    func didImported(contract: AlphaWallet.Address, in coordinator: UniversalLinkCoordinator)
}

class UniversalLinkCoordinator: Coordinator {
    private enum TransactionType {
        case freeTransfer(query: String, parameters: Parameters)
        case paid(signedOrder: SignedOrder, tokenObject: TokenObject)
    }

    private let config: Config
	private var importTokenViewController: ImportMagicTokenViewController?
    private let ethPrice: Subscribable<Double>
    private let ethBalance: Subscribable<BigInt>
    private var hasCompleted = false
    private var getERC875TokenBalanceCoordinator: GetERC875BalanceCoordinator?
    //TODO better to make sure tokenHolder is non-optional. But be careful that ImportMagicTokenViewController also handles when viewModel always has a TokenHolder. Needs good defaults in TokenHolder that can be displayed
    private var tokenHolder: TokenHolder?
    private var count: Decimal?
    private var transactionType: TransactionType?
    private var isShowingImportUserInterface: Bool {
        return delegate?.viewControllerForPresenting(in: self) != nil
    }
    private let tokensDatastores: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore
    private let url: URL

    private var isNotProcessingYet: Bool {
        guard let importTokenViewController = importTokenViewController else { return false }
        switch importTokenViewController.state {
        case .ready(let viewModel):
            switch viewModel.state {
            case .validating, .promptImport:
                return true
            case .processing, .succeeded, .failed:
                return false
            }
        case .notReady:
            return false
        }
    }
    private var walletAddress: AlphaWallet.Address {
        //TODO pass in the wallet instead
        return EtherKeystore.current!.address
    }

    var coordinators: [Coordinator] = []
    let server: RPCServer
    weak var delegate: UniversalLinkCoordinatorDelegate?

    //no need to localise as the labels are universal
    private var labelForCurrencyDrops: String {
        switch server {
        case .xDai:
            return "xDAI"
        default:
            return "ETH"
        }
    }

    init?(config: Config, ethPrices: ServerDictionary<Subscribable<Double>>, ethBalances: ServerDictionary<Subscribable<BigInt>>, tokensDatastores: ServerDictionary<TokensDataStore>, assetDefinitionStore: AssetDefinitionStore, url: URL) {
        guard let server = RPCServer(withMagicLink: url) else { return nil }

        self.config = config
        self.ethPrice = ethPrices[server]
        self.ethBalance = ethBalances[server]
        self.tokensDatastores = tokensDatastores
        self.assetDefinitionStore = assetDefinitionStore
        self.url = url
        self.server = server
    }

	func start() {
	}

    private func createHTTPParametersForCurrencyLinksToPaymentServer(
            signedOrder: SignedOrder,
            recipient: AlphaWallet.Address
    ) -> Parameters {
        let signature = signedOrder.signature.drop0x
        let parameters: Parameters = [
            "prefix": Constants.xdaiDropPrefix,
            "recipient": recipient.eip55String,
            "amount": signedOrder.order.count.description,
            "expiry": signedOrder.order.expiry.description,
            "nonce": signedOrder.order.nonce,
            "v": signature.substring(from: 128),
            "r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
            "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128))),
            "networkId": server.chainID.description,
            "contractAddress": signedOrder.order.contractAddress
        ]
        return parameters
    }

    private func createHTTPParametersForNormalLinksToPaymentServer(
            signedOrder: SignedOrder,
            isForTransfer: Bool
    ) -> Parameters {
        // form the json string out of the order for the paymaster server
        // James S. wrote
        let keystore = try! EtherKeystore()
        let signature = signedOrder.signature.drop0x
        let indices = signedOrder.order.indices
        let indicesStringEncoded = stringEncodeIndices(indices)
        var parameters: Parameters = [
            "address": walletAddress,
            "contractAddress": signedOrder.order.contractAddress,
            "indices": indicesStringEncoded,
            "price": signedOrder.order.price.description,
            "expiry": signedOrder.order.expiry.description,
            "v": signature.substring(from: 128),
            "r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
            "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128))),
            "networkId": server.chainID.description,
        ]
        
        if isForTransfer {
            parameters.removeValue(forKey: "price")
        }
        
        return parameters
    }

    @discardableResult private func handlePaidImportsImpl(signedOrder: SignedOrder) -> Bool {
        guard isShowingImportUserInterface else { return false }

        //TODO we might not need to pass a TokenObject. Maybe something simpler? Especially since name and symbol is unused
        //TODO: not always ERC875
        let tokenObject = TokenObject(
                contract: signedOrder.order.contractAddress,
                server: server,
                name: "",
                symbol: "",
                decimals: 0,
                value: signedOrder.order.price.description,
                isCustom: true,
                isDisabled: false,
                type: .erc875
        )
        transactionType = .paid(signedOrder: signedOrder, tokenObject: tokenObject)

        let ethCost = convert(ethCost: signedOrder.order.price)
        promptImportUniversalLink(cost: .paid(eth: ethCost, dollar: nil))
        ethPrice.subscribe { [weak self] value in
            guard let celf = self else { return }
            guard let price = celf.ethPrice.value else { return }
            let (ethCost, dollarCost) = celf.convert(ethCost: signedOrder.order.price, rate: price)
            //We should not prompt with an updated price if we are already processing or beyond that. Because this will revert the state back
            if celf.isNotProcessingYet {
                celf.promptImportUniversalLink(cost: .paid(eth: ethCost, dollar: dollarCost))
            }
        }
        return true
    }

    @discardableResult private func usePaymentServerForFreeTransferLinks(signedOrder: SignedOrder) -> Bool {
        guard isShowingImportUserInterface else { return false }
        guard let (parameters, query) = getParametersAndQuery(signedOrder: signedOrder) else { return false }
        transactionType = .freeTransfer(query: query, parameters: parameters)
        promptImportUniversalLink(cost: .free)
        return true
    }

    private func getParametersAndQuery(signedOrder: SignedOrder) -> (Parameters, String)? {
        let parameters: Parameters
        let query: String
        switch signedOrder.order.nativeCurrencyDrop {
            case true:
                parameters = createHTTPParametersForCurrencyLinksToPaymentServer(
                        signedOrder: signedOrder,
                        recipient: walletAddress
                )
                query = Constants.currencyDropServer
            case false:
                parameters = createHTTPParametersForNormalLinksToPaymentServer(
                        signedOrder: signedOrder,
                        isForTransfer: true
                )
                query = Constants.paymentServer
        }
        return (parameters, query)
    }

    func completeOrderHandling(signedOrder: SignedOrder) {
        let requiresPaymaster = requiresPaymasterForCurrencyLinks(signedOrder: signedOrder)
        if signedOrder.order.price == 0 {
            checkPaymentServerSupportsContract(contractAddress: signedOrder.order.contractAddress) { supported in
                //Currency links on mainnet/classic/xdai without a paymaster should be rejected for security reasons (front running)
                guard supported || !requiresPaymaster else {
                    self.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedServerDown())
                    return
                }
                if supported {
                    self.usePaymentServerForFreeTransferLinks(signedOrder: signedOrder)
                } else {
                    self.handlePaidImports(signedOrder: signedOrder)
                }
            }
        } else {
            self.handlePaidImports(signedOrder: signedOrder)
        }
    }

    private func requiresPaymasterForCurrencyLinks(signedOrder: SignedOrder) -> Bool {
        guard signedOrder.order.nativeCurrencyDrop else { return false }
        guard signedOrder.order.price == 0 else { return false }
        return !server.isTestnet
    }

    private func handleSpawnableLink(signedOrder: SignedOrder, tokens: [BigUInt]) {
        let tokenStrings: [String] = tokens.map { String($0, radix: 16) }
        self.makeTokenHolder(
                tokenStrings,
                signedOrder.order.contractAddress
        )
        completeOrderHandling(signedOrder: signedOrder)
    }

    private func handleNativeCurrencyDrop(signedOrder: SignedOrder) {
        let amt: Decimal
        let szabosPerEth: Decimal = Decimal(EthereumUnit.ether.rawValue / EthereumUnit.szabo.rawValue)
        //TODO should be better to put this into the tokenCount that is displayed in green
        if let amount = Decimal(string: signedOrder.order.count.description) {
            amt = amount / szabosPerEth
        } else {
            amt = 0
        }
        count = amt
        let token = Token(
                id: 0,
                index: 0,
                name: labelForCurrencyDrops,
                symbol: "",
                status: .available,
                values: [:]
        )
        self.tokenHolder = TokenHolder(
                tokens: [token],
                contractAddress: signedOrder.order.contractAddress,
                hasAssetDefinition: false
        )
        let r = signedOrder.signature.substring(with: Range(uncheckedBounds: (2, 66)))
        checkIfLinkClaimed(r: r) { claimed in
            if claimed {
                self.showImportError(errorMessage: R.string.localizable.aClaimTokenLinkAlreadyRedeemed())
            } else {
                self.completeOrderHandling(signedOrder: signedOrder)
            }
        }
    }

    private func handleNormalLinks(signedOrder: SignedOrder, recoverAddress: AlphaWallet.Address, contractAsAddress: AlphaWallet.Address) {
        getERC875TokenBalanceCoordinator = GetERC875BalanceCoordinator(forServer: server)
        getERC875TokenBalanceCoordinator?.getERC875TokenBalance(for: recoverAddress, contract: contractAsAddress) { [weak self] result in
            guard let strongSelf = self else { return }
            guard let balance = try? result.dematerialize() else {
                if let reachabilityManager = NetworkReachabilityManager(), !reachabilityManager.isReachable {
                    strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenNoConnectivityTryAgain())
                } else {
                    strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
                }
                return
            }

            let filteredTokens: [String] = strongSelf.checkERC875TokensAreAvailable(
                    indices: signedOrder.order.indices,
                    balance: balance
            )
            if filteredTokens.isEmpty {
                strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenLinkAlreadyRedeemed())
                return
            }

            strongSelf.makeTokenHolder(
                    filteredTokens,
                    signedOrder.order.contractAddress
            )

            strongSelf.completeOrderHandling(signedOrder: signedOrder)
        }
    }

    private func isOrderExpired(_ signedOrder: SignedOrder) -> Bool {
        return Date(timeIntervalSince1970: TimeInterval(signedOrder.order.expiry)).isEarlierThan(date: Date())
    }

    //Returns true if handled
    func handleUniversalLink() -> Bool {
        preparingToImportUniversalLink()
        let isLegacyLink = url.description.hasPrefix(Constants.legacyMagicLinkPrefix)
        let prefix: String
        if isLegacyLink {
            prefix = Constants.legacyMagicLinkPrefix
        } else {
            prefix = server.magicLinkPrefix.description
        }
        guard let signedOrder = UniversalLinkHandler(server: server).parseUniversalLink(url: url.absoluteString, prefix: prefix) else {
            showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
            return false
        }
        importTokenViewController?.url = url
        importTokenViewController?.contract = signedOrder.order.contractAddress

        if isOrderExpired(signedOrder) {
            showImportError(errorMessage: R.string.localizable.aClaimTokenLinkExpired())
            return true
        }

        let recoveredSigner = ecrecover(signedOrder: signedOrder)
        switch recoveredSigner {
        case .success(let ethereumAddress):
            let recoverAddress = AlphaWallet.Address(address: ethereumAddress)
            if signedOrder.order.nativeCurrencyDrop {
                handleNativeCurrencyDrop(signedOrder: signedOrder)
            } else if signedOrder.order.spawnable, let tokens = signedOrder.order.tokenIds {
                handleSpawnableLink(signedOrder: signedOrder, tokens: tokens)
            } else {
                handleNormalLinks(
                        signedOrder: signedOrder,
                        recoverAddress: recoverAddress,
                        contractAsAddress: signedOrder.order.contractAddress
                )
            }
        case .failure(let error):
            print("ecrecover error: " + error.localizedDescription)
            self.showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
            return false
        }
        return true
    }

    private func checkPaymentServerSupportsContract(contractAddress: AlphaWallet.Address, completionHandler: @escaping (Bool) -> Void) {
        let parameters: Parameters = [
            "contractAddress": contractAddress.eip55String
        ]
        Alamofire.request(
                Constants.paymentServerSupportsContractEndPoint,
                method: .get,
                parameters: parameters
        ).responseJSON { result in
            if let response = result.response {
                let supported = response.statusCode >= 200 && response.statusCode <= 299
                completionHandler(supported)
            } else {
                completionHandler(false)
            }
        }
    }

    private func checkIfLinkClaimed(r: String, completionHandler: @escaping (Bool) -> Void) {
        let parameters: Parameters = [ "r": r ]
        Alamofire.request(
                Constants.paymentServerClaimedToken,
                method: .get,
                parameters: parameters
        ).responseJSON { result in
            if let response = result.response {
                if response.statusCode == 208 || response.statusCode > 299 {
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            } else {
                completionHandler(false)
            }
        }
    }

    private func ecrecover(signedOrder: SignedOrder) -> ResultResult<web3swift.EthereumAddress, web3swift.Web3Error>.t {
        //need to hash message here because the web3swift implementation adds prefix
        let messageHash = Data(bytes: signedOrder.message).sha3(.keccak256)
        //note: web3swift takes the v value as v - 27, so we need to manually convert this
        let vValue = signedOrder.signature.drop0x.substring(from: 128)
        let vInt = Int(vValue, radix: 16)! - 27
        let vString = "0" + String(vInt)
        let signature = "0x" + signedOrder.signature.drop0x.substring(to: 128) + vString
        let nodeURL = server.rpcURL
        let provider = Web3HttpProvider(nodeURL, network: server.web3Network)!
        return web3(provider: provider).personal.ecrecover(
                hash: messageHash,
                signature: Data(bytes: signature.hexa2Bytes)
        )
    }
    
    private func handlePaidImports(signedOrder: SignedOrder) {
        ethBalance.subscribeOnce { [weak self] value in
            guard let celf = self else { return }
            if value > signedOrder.order.price {
                celf.handlePaidImportsImpl(signedOrder: signedOrder)
            } else {
                celf.notEnoughEthForPaidImport(signedOrder: signedOrder)
            }
        }
    }

    private func notEnoughEthForPaidImport(signedOrder: SignedOrder) {
        let errorMessage: String
        switch server {
        case .xDai:
            errorMessage = R.string.localizable.aClaimTokenFailedNotEnoughXDAITitle()
        default:
            errorMessage = R.string.localizable.aClaimTokenFailedNotEnoughEthTitle()
        }
        if ethPrice.value == nil {
            let ethCost = convert(ethCost: signedOrder.order.price)
            showImportError(
                errorMessage: errorMessage,
                cost: .paid(eth: ethCost, dollar: nil)
            )
        }
        ethPrice.subscribe { [weak self] value in
            guard let celf = self else { return }
            guard let price = celf.ethPrice.value else { return }
            let (ethCost, dollarCost) = celf.convert(ethCost: signedOrder.order.price, rate: price)
            celf.showImportError(errorMessage: errorMessage,
                    cost: .paid(eth: ethCost, dollar: dollarCost))
        }
    }

    private func stringEncodeIndices(_ indices: [UInt16]) -> String {
        return indices.map(String.init).joined(separator: ",")
    }

    private func checkERC875TokensAreAvailable(indices: [UInt16], balance: [String]) -> [String] {
        var filteredTokens = [String]()
        if balance.count < indices.count {
            return [String]()
        }
        for i in 0..<indices.count {
            let token: String = balance[Int(indices[i])]
            //all of the indices provided should map to a valid non null token
            if isZeroBalance(token) {
                //if null token at any index then the deal cannot happen
                return [String]()
            }
            filteredTokens.append(token)
        }
        return filteredTokens
    }

    private func makeTokenHolder(_ bytes32Tokens: [String], _ contractAddress: AlphaWallet.Address) {
        assetDefinitionStore.fetchXML(forContract: contractAddress, useCacheAndFetch: true) { [weak self] result in
            guard let strongSelf = self else { return }

            func makeTokenHolder(name: String, symbol: String) {
                strongSelf.makeTokenHolderImpl(name: name, symbol: symbol, bytes32Tokens: bytes32Tokens, contractAddress: contractAddress)
                strongSelf.updateTokenFields()
            }

            let tokensDatastore = strongSelf.tokensDatastores[strongSelf.server]
            if let existingToken = tokensDatastore.token(forContract: contractAddress) {
                let name = XMLHandler(contract: existingToken.contractAddress, assetDefinitionStore: strongSelf.assetDefinitionStore).getName(fallback: existingToken.name)
                makeTokenHolder(name: name, symbol: existingToken.symbol)
            } else {
                let localizedTokenTypeName = R.string.localizable.tokensTitlecase()
                makeTokenHolder(name: localizedTokenTypeName, symbol: "")

                let getContractName = tokensDatastore.getContractName(for: contractAddress)
                let getContractSymbol = tokensDatastore.getContractSymbol(for: contractAddress)
                firstly {
                    when(fulfilled: getContractName, getContractSymbol)
                }.done { name, symbol in
                    makeTokenHolder(name: name, symbol: symbol)
                }
            }
        }
    }

    private func makeTokenHolderImpl(name: String, symbol: String, bytes32Tokens: [String], contractAddress: AlphaWallet.Address) {
        //TODO pass in the wallet instead
        let account = EtherKeystore.current!
        var tokens = [Token]()
        let xmlHandler = XMLHandler(contract: contractAddress, assetDefinitionStore: assetDefinitionStore)
        for i in 0..<bytes32Tokens.count {
            let token = bytes32Tokens[i]
            if let tokenId = BigUInt(token.drop0x, radix: 16) {
                let token = xmlHandler.getToken(name: name, symbol: symbol, fromTokenId: tokenId, index: UInt16(i), inWallet: account, server: server)
                tokens.append(token)
            }
        }
        tokenHolder = TokenHolder(
                tokens: tokens,
                contractAddress: contractAddress,
                hasAssetDefinition: xmlHandler.hasAssetDefinition
        )
    }

	private func preparingToImportUniversalLink() {
		guard let viewController = delegate?.viewControllerForPresenting(in: self) else { return }
        importTokenViewController = ImportMagicTokenViewController(server: server, assetDefinitionStore: assetDefinitionStore)
        guard let vc = importTokenViewController else { return }
        vc.delegate = self
        vc.configure(viewModel: .init(state: .validating, server: server))
        viewController.present(UINavigationController(rootViewController: vc), animated: true)
	}

    private func updateTokenFields() {
        guard let tokenHolder = tokenHolder else { return }
        guard let vc = importTokenViewController, case .ready(var viewModel) = vc.state else { return }
        viewModel.tokenHolder = tokenHolder
        viewModel.count = count
        vc.configure(viewModel: viewModel)
    }

    private func updateImportTokenController(with state: ImportMagicTokenViewControllerViewModel.State, cost: ImportMagicTokenViewControllerViewModel.Cost? = nil) {
        guard !hasCompleted else { return }
        if let vc = importTokenViewController, case .ready(var viewModel) = vc.state {
            viewModel.state = state
            if let tokenHolder = tokenHolder {
                viewModel.tokenHolder = tokenHolder
                viewModel.count = count
            }
            if let cost = cost {
                viewModel.cost = cost
            }
            vc.configure(viewModel: viewModel)
        }
        hasCompleted = state.hasCompleted
    }

	private func promptImportUniversalLink(cost: ImportMagicTokenViewControllerViewModel.Cost) {
		updateImportTokenController(with: .promptImport, cost: cost)
    }

	private func showImportSuccessful() {
		updateImportTokenController(with: .succeeded)
		promptBackupWallet()
	}

    private func promptBackupWallet() {
        guard let keystore = try? EtherKeystore() else { return }
		let coordinator = PromptBackupCoordinator(keystore: keystore, walletAddress: walletAddress, config: config)
		addCoordinator(coordinator)
		coordinator.delegate = self
		coordinator.start()
	}

    private func showImportError(errorMessage: String, cost: ImportMagicTokenViewControllerViewModel.Cost? = nil) {
        updateImportTokenController(with: .failed(errorMessage: errorMessage), cost: cost)
	}

    private func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject) {
        updateImportTokenController(with: .processing)
        delegate?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject) { [weak self] successful in
            guard let strongSelf = self else { return }
            guard let vc = strongSelf.importTokenViewController, case .ready = vc.state else { return }
            if successful {
                strongSelf.delegate?.didImported(contract: signedOrder.order.contractAddress, in: strongSelf)
                strongSelf.showImportSuccessful()
            } else {
                //TODO Pass in error message
                strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedTitle())
            }
        }
    }

	private func importFreeTransfer(query: String, parameters: Parameters) {
		updateImportTokenController(with: .processing)

        Alamofire.request(
                query,
                method: .post,
                parameters: parameters
        ).responseJSON { [weak self] result in
            guard let strongSelf = self else { return }
            var successful = false //need to set this to false by default else it will allow no connections to be considered successful etc
            //401 code will be given if signature is invalid on the server
            if let response = result.response {
                if response.statusCode < 300 {
                    successful = true
                    if let contract = (parameters["contractAddress"] as? String).flatMap({ AlphaWallet.Address(string: $0) }) {
                        strongSelf.delegate?.didImported(contract: contract, in: strongSelf)
                    }
                }
            }

            guard let vc = strongSelf.importTokenViewController, case .ready = vc.state else { return }
            // TODO handle http response
            print(result)
            if successful {
                strongSelf.showImportSuccessful()
            } else {
                //TODO Pass in error message
                strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedTitle())
            }
        }
    }

    private func convert(ethCost: BigUInt, rate: Double) -> (ethCost: Decimal, dollarCost: Decimal) {
        let etherCostDecimal = convert(ethCost: ethCost)
        let dollarCost = Decimal(rate) * etherCostDecimal
        return (etherCostDecimal, dollarCost)
    }

    private func convert(ethCost: BigUInt) -> Decimal {
        //TODO extract constant. Used elsewhere too
        let divideAmount = Decimal(string: "1000000000000000000")!
        let etherCostDecimal = Decimal(string: ethCost.description)! / divideAmount
        return etherCostDecimal
    }
}

extension UniversalLinkCoordinator: ImportMagicTokenViewControllerDelegate {
	func didPressDone(in viewController: ImportMagicTokenViewController) {
		viewController.dismiss(animated: true)
		delegate?.completed(in: self)
	}

	func didPressImport(in viewController: ImportMagicTokenViewController) {
        guard let transactionType = transactionType else { return }
        switch transactionType {
        case .freeTransfer(let query, let parameters):
            importFreeTransfer(query: query, parameters: parameters)
        case .paid(let signedOrder, let tokenObject):
            importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject)
        }
	}
}

extension UniversalLinkCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension UniversalLinkCoordinator: PromptBackupCoordinatorDelegate {
	func viewControllerForPresenting(in coordinator: PromptBackupCoordinator) -> UIViewController? {
		return delegate?.viewControllerForPresenting(in: self)
	}

	func didFinish(in coordinator: PromptBackupCoordinator) {
		removeCoordinator(coordinator)
	}
}
