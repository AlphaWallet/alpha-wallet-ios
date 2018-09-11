// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import BigInt
import RealmSwift
import TrustKeystore
import web3swift

protocol UniversalLinkCoordinatorDelegate: class, CanOpenURL {
	func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController?
	func completed(in coordinator: UniversalLinkCoordinator)
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void)
    func didImported(contract: String, in coordinator: UniversalLinkCoordinator)
}

class UniversalLinkCoordinator: Coordinator {
    private enum TransactionType {
        case freeTransfer(query: String, parameters: Parameters)
        case paid(signedOrder: SignedOrder, tokenObject: TokenObject)
    }

	var coordinators: [Coordinator] = []
    private let config: Config
	weak var delegate: UniversalLinkCoordinatorDelegate?
	private var importTokenViewController: ImportMagicTokenViewController?
    private let ethPrice: Subscribable<Double>
    private let ethBalance: Subscribable<BigInt>
    private var hasCompleted = false
    private var getERC875TokenBalanceCoordinator: GetERC875BalanceCoordinator?
    //TODO better to make sure tokenHolder is non-optional. But be careful that ImportMagicTokenViewController also handles when viewModel always has a TokenHolder. Needs good defaults in TokenHolder that can be displayed
    private var tokenHolder: TokenHolder?
    private var transactionType: TransactionType?
    private var isShowingImportUserInterface: Bool {
        return delegate?.viewControllerForPresenting(in: self) != nil
    }
    private let tokensDatastore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore

    init(config: Config, ethPrice: Subscribable<Double>, ethBalance: Subscribable<BigInt>, tokensDatastore: TokensDataStore, assetDefinitionStore: AssetDefinitionStore) {
        self.config = config
        self.ethPrice = ethPrice
        self.ethBalance = ethBalance
        self.tokensDatastore = tokensDatastore
        self.assetDefinitionStore = assetDefinitionStore
    }

	func start() {
	}
    
    private func createHTTPParametersForPaymentServer(signedOrder: SignedOrder, isForTransfer: Bool) -> Parameters {
        // form the json string out of the order for the paymaster server
        // James S. wrote
        let keystore = try! EtherKeystore()
        let signature = signedOrder.signature.substring(from: 2)
        let indices = signedOrder.order.indices
        let indicesStringEncoded = stringEncodeIndices(indices)
        let address = (keystore.recentlyUsedWallet?.address.eip55String)!
        var parameters: Parameters = [
            "address": address,
            "contractAddress": signedOrder.order.contractAddress,
            "indices": indicesStringEncoded,
            "price": signedOrder.order.price.description,
            "expiry": signedOrder.order.expiry.description,
            "v": signature.substring(from: 128),
            "r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
            "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128))),
            "networkId": config.chainID.description,
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
        let tokenObject = TokenObject(contract: signedOrder.order.contractAddress,
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
            celf.promptImportUniversalLink(cost: .paid(eth: ethCost, dollar: dollarCost))
        }
        return true
    }

    @discardableResult private func usePaymentServerForFreeTransferLinks(signedOrder: SignedOrder) -> Bool {
        guard isShowingImportUserInterface else { return false }

        let parameters = createHTTPParametersForPaymentServer(signedOrder: signedOrder, isForTransfer: true)
        let query = Constants.paymentServer
        transactionType = .freeTransfer(query: query, parameters: parameters)
        promptImportUniversalLink(cost: .free)
        return true
    }

    //Returns true if handled
    func handleUniversalLink(url: URL) -> Bool {
        let prefix = UniversalLinkHandler().urlPrefix
        let matchedPrefix = url.description.hasPrefix(prefix)
        preparingToImportUniversalLink()
        guard matchedPrefix, url.absoluteString.count > prefix.count else {
            showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
            return false
        }
        guard let signedOrder = UniversalLinkHandler().parseUniversalLink(url: url.absoluteString) else {
            showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
            return false
        }
        let isVerified = XMLHandler(contract: signedOrder.order.contractAddress).isVerified(for: config.server)
        let isStormBirdContract = isVerified
        importTokenViewController?.url = url
        importTokenViewController?.contract = signedOrder.order.contractAddress
        let recoveredSigner = ecrecover(signedOrder: signedOrder)
        switch recoveredSigner {
        case .success(let ethereumAddress):
            //TODO extract method for the whole .success? Quite long
            guard let recoverAddress = Address(string: ethereumAddress.address) else { return false }
            let contractAsAddress = Address(string: signedOrder.order.contractAddress)!
            //gather signer address balance
            let web3Swift = Web3Swift()
            web3Swift.start()
            getERC875TokenBalanceCoordinator = GetERC875BalanceCoordinator(config: config)
            getERC875TokenBalanceCoordinator?.getERC875TokenBalance(for: recoverAddress, contract: contractAsAddress) { [weak self] result in
                guard let strongSelf = self else { return }
                guard let balance = try? result.dematerialize() else {
                    strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
                    return
                }
                //filter null tokens
                let filteredTokens = strongSelf.checkERC875TokensAreAvailable(
                        indices: signedOrder.order.indices,
                        balance: balance
                )
                if filteredTokens.isEmpty {
                    strongSelf.showImportError(errorMessage: R.string.localizable.aClaimTokenInvalidLinkTryAgain())
                    return
                }

                strongSelf.makeTokenHolder(
                        filteredTokens,
                        signedOrder.order.indices,
                        signedOrder.order.contractAddress
                )

                if signedOrder.order.price == 0 && isStormBirdContract {
                    strongSelf.checkPaymentServerSupportsContract(contractAddress: signedOrder.order.contractAddress) { supported in
                        if supported {
                            strongSelf.usePaymentServerForFreeTransferLinks(signedOrder: signedOrder)
                        } else {
                            strongSelf.handlePaidImports(signedOrder: signedOrder)
                        }
                    }
                } else {
                    strongSelf.handlePaidImports(signedOrder: signedOrder)
                }
            }
        case .failure(let error):
            //TODO handle. Show error maybe?
            NSLog("xxx error during ecrecover: \(error.localizedDescription)")
            return false
        }
        return true
    }

    private func checkPaymentServerSupportsContract(contractAddress: String, completionHandler: @escaping (Bool) -> Void) {
        let parameters: Parameters = [
            "contractAddress": contractAddress
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

    private func ecrecover(signedOrder: SignedOrder) -> ResultResult<web3swift.EthereumAddress, web3swift.Web3Error>.t {
        //need to hash message here because the web3swift implementation adds prefix
        let messageHash = Data(bytes: signedOrder.message).sha3(.keccak256)
        //note: web3swift takes the v value as v - 27, so we need to manually convert this
        let vValue = signedOrder.signature.drop0x.substring(from: 128)
        let vInt = Int(vValue, radix: 16)! - 27
        let vString = "0" + String(vInt)
        let signature = "0x" + signedOrder.signature.drop0x.substring(to: 128) + vString
        let nodeURL = config.rpcURL
        return web3(provider: Web3HttpProvider(nodeURL, network: config.server.web3Network)!).personal.ecrecover(
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
        if ethPrice.value == nil {
            let ethCost = convert(ethCost: signedOrder.order.price)
            showImportError(
                errorMessage: R.string.localizable.aClaimTokenFailedNotEnoughEthTitle(),
                cost: .paid(eth: ethCost, dollar: nil)
            )
        }
        ethPrice.subscribe { [weak self] value in
            guard let celf = self else { return }
            guard let price = celf.ethPrice.value else { return }
            let (ethCost, dollarCost) = celf.convert(ethCost: signedOrder.order.price, rate: price)
            celf.showImportError(errorMessage: R.string.localizable.aClaimTokenFailedNotEnoughEthTitle(),
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

    private func makeTokenHolder(_ bytes32Tokens: [String], _ indices: [UInt16], _ contractAddress: String) {
        assetDefinitionStore.fetchXML(forContract: contractAddress, useCacheAndFetch: true) { [weak self] result in
            guard let strongSelf = self else { return }

            func makeTokenHolder(name: String) {
                strongSelf.makeTokenHolderImpl(name: name, bytes32Tokens: bytes32Tokens, contractAddress: contractAddress)
                strongSelf.updateTokenFields()
            }

            if let existingToken = strongSelf.tokensDatastore.objects.first(where: { $0.contract.sameContract(as: contractAddress) }) {
                makeTokenHolder(name: existingToken.name)
            } else {
                let localizedTokenTypeName = R.string.localizable.tokensTitlecase()
                makeTokenHolder(name: localizedTokenTypeName )

                strongSelf.tokensDatastore.getContractName(for: contractAddress) { result in
                    switch result {
                    case .success(let name):
                        makeTokenHolder(name: name)
                    case .failure:
                        break
                    }
                }
            }
        }
    }

    private func makeTokenHolderImpl(name: String, bytes32Tokens: [String], contractAddress: String) {
        var tokens = [Token]()
        let xmlHandler = XMLHandler(contract: contractAddress)
        for i in 0..<bytes32Tokens.count {
            let token = bytes32Tokens[i]
            if let tokenId = BigUInt(token.drop0x, radix: 16) {
                let token = xmlHandler.getToken(name: name, fromTokenId: tokenId, index: UInt16(i))
                tokens.append(token)
            }
        }
        tokenHolder = TokenHolder(
                tokens: tokens,
                status: .available,
                contractAddress: contractAddress,
                hasAssetDefinition: xmlHandler.hasAssetDefinition
        )
    }

	private func preparingToImportUniversalLink() {
		guard let viewController = delegate?.viewControllerForPresenting(in: self) else { return }
        importTokenViewController = ImportMagicTokenViewController(config: config)
        guard let vc = importTokenViewController else { return }
        vc.delegate = self
        vc.configure(viewModel: .init(state: .validating))
        viewController.present(UINavigationController(rootViewController: vc), animated: true)
	}

    private func updateTokenFields() {
        guard let tokenHolder = tokenHolder else { return }
        guard let vc = importTokenViewController, case .ready(var viewModel) = vc.state else { return }
        viewModel.tokenHolder = tokenHolder
        vc.configure(viewModel: viewModel)
    }

    private func updateImportTokenController(with state: ImportMagicTokenViewControllerViewModel.State, cost: ImportMagicTokenViewControllerViewModel.Cost? = nil) {
        guard !hasCompleted else { return }
        if let vc = importTokenViewController, case .ready(var viewModel) = vc.state {
            viewModel.state = state
            if let tokenHolder = tokenHolder {
                viewModel.tokenHolder = tokenHolder
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
        guard let keystore = try? EtherKeystore(), let address = keystore.recentlyUsedWallet?.address.eip55String else { return }
		let coordinator = PromptBackupCoordinator(walletAddress: address)
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
                    if let contract = parameters["contractAddress"] as? String {
                        strongSelf.delegate?.didImported(contract: contract, in: strongSelf)
                    }
                }
            }

            guard let vc = strongSelf.importTokenViewController, case .ready(var viewModel) = vc.state else { return }
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
    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, in: viewController)
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
