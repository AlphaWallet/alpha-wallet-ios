// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import BigInt
import Realm
import TrustKeystore
import web3swift

protocol UniversalLinkCoordinatorDelegate: class {
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
	private var importTicketViewController: ImportTicketViewController?
    private let ethPrice: Subscribable<Double>
    private let ethBalance: Subscribable<BigInt>
    private var hasCompleted = false
    private var addressOfNewWallet: String?
    private var getERC875TokenBalanceCoordinator: GetERC875BalanceCoordinator?
    //TODO better to make sure ticketHolder is non-optional. But be careful that ImportTicketViewController also handles when viewModel always has a TicketHolder. Needs good defaults in TicketHolder that can be displayed
    private var ticketHolder: TokenHolder?
    private var transactionType: TransactionType?
    private var isShowingImportUserInterface: Bool {
        return delegate?.viewControllerForPresenting(in: self) != nil
    }

    init(config: Config, ethPrice: Subscribable<Double>, ethBalance: Subscribable<BigInt>) {
        self.config = config
        self.ethPrice = ethPrice
        self.ethBalance = ethBalance
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

        //TODO: not always ERC875
        let tokenObject = TokenObject(contract: signedOrder.order.contractAddress,
                name: Constants.event,
                symbol: "FIFA",
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
            showImportError(errorMessage: R.string.localizable.aClaimTicketInvalidLinkTryAgain())
            return false
        }
        guard let signedOrder = UniversalLinkHandler().parseUniversalLink(url: url.absoluteString) else {
            showImportError(errorMessage: R.string.localizable.aClaimTicketInvalidLinkTryAgain())
            return false
        }
        let isVerified = XMLHandler(contract: signedOrder.order.contractAddress).isVerified(for: config.server)
        let isStormBirdContract = isVerified
        importTicketViewController?.url = url
        importTicketViewController?.contract = signedOrder.order.contractAddress
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
            getERC875TokenBalanceCoordinator?.getERC875TokenBalance(for: recoverAddress, contract: contractAsAddress) { result in
                guard let balance = try? result.dematerialize() else {
                    self.showImportError(errorMessage: R.string.localizable.aClaimTicketInvalidLinkTryAgain())
                    return
                }
                //filter null tickets
                let filteredTokens = self.checkERC875TokensAreAvailable(
                        indices: signedOrder.order.indices,
                        balance: balance
                )
                if filteredTokens.isEmpty {
                    self.showImportError(errorMessage: R.string.localizable.aClaimTicketInvalidLinkTryAgain())
                    return
                }

                self.makeTicketHolder(
                        filteredTokens,
                        signedOrder.order.indices,
                        signedOrder.order.contractAddress
                )

                if signedOrder.order.price > 0 || !isStormBirdContract {
                    self.handlePaidImports(signedOrder: signedOrder)
                } else {
                    self.usePaymentServerForFreeTransferLinks(signedOrder: signedOrder)
                }
            }
        case .failure(let error):
            //TODO handle. Show error maybe?
            NSLog("xxx error during ecrecover: \(error.localizedDescription)")
            return false
        }
        return true
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
                errorMessage: R.string.localizable.aClaimTicketFailedNotEnoughEthTitle(),
                cost: .paid(eth: ethCost, dollar: nil)
            )
        }
        ethPrice.subscribe { [weak self] value in
            guard let celf = self else { return }
            guard let price = celf.ethPrice.value else { return }
            let (ethCost, dollarCost) = celf.convert(ethCost: signedOrder.order.price, rate: price)
            celf.showImportError(errorMessage: R.string.localizable.aClaimTicketFailedNotEnoughEthTitle(),
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
            //all of the indices provided should map to a valid non null ticket
            if isZeroBalance(token) {
                //if null ticket at any index then the deal cannot happen
                return [String]()
            }
            filteredTokens.append(token)
        }
        return filteredTokens
    }

    private func makeTicketHolder(_ bytes32Tickets: [String], _ indices: [UInt16], _ contractAddress: String) {
        //TODO better to pass in the store instance once UniversalLinkCoordinator is owned by InCoordinator
        AssetDefinitionStore().fetchXML(forContract: contractAddress, useCacheAndFetch: true) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .cached:
                strongSelf.makeTicketHolderImpl(bytes32Tickets: bytes32Tickets, contractAddress: contractAddress)
            case .updated:
                strongSelf.makeTicketHolderImpl(bytes32Tickets: bytes32Tickets, contractAddress: contractAddress)
                strongSelf.updateTicketFields()
            case .unmodified, .error:
                break
            }
        }
    }

    private func makeTicketHolderImpl(bytes32Tickets: [String], contractAddress: String) {
        var tickets = [Ticket]()
        let xmlHandler = XMLHandler(contract: contractAddress)
        for i in 0..<bytes32Tickets.count {
            let ticket = bytes32Tickets[i]
            if let tokenId = BigUInt(ticket.drop0x, radix: 16) {
                let ticket = xmlHandler.getFifaInfoForTicket(tokenId: tokenId, index: UInt16(i))
                tickets.append(ticket)
            }
        }
        ticketHolder = TokenHolder(
                tickets: tickets,
                status: .available,
                contractAddress: contractAddress
        )
    }

	private func preparingToImportUniversalLink() {
		guard let viewController = delegate?.viewControllerForPresenting(in: self) else { return }
        importTicketViewController = ImportTicketViewController(config: config)
        guard let vc = importTicketViewController else { return }
        vc.delegate = self
        vc.configure(viewModel: .init(state: .validating))
        viewController.present(UINavigationController(rootViewController: vc), animated: true)
	}

    private func updateTicketFields() {
        guard let ticketHolder = ticketHolder else { return }
        guard let vc = importTicketViewController, case .ready(var viewModel) = vc.state else { return }
        viewModel.ticketHolder = ticketHolder
        vc.configure(viewModel: viewModel)
    }

    private func updateImportTicketController(with state: ImportTicketViewControllerViewModel.State, cost: ImportTicketViewControllerViewModel.Cost? = nil) {
        guard !hasCompleted else { return }
        if let vc = importTicketViewController, case .ready(var viewModel) = vc.state {
            viewModel.state = state
            if let ticketHolder = ticketHolder {
                viewModel.ticketHolder = ticketHolder
            }
            if let cost = cost {
                viewModel.cost = cost
            }
            vc.configure(viewModel: viewModel)
        }
        hasCompleted = state.hasCompleted
    }

	private func promptImportUniversalLink(cost: ImportTicketViewControllerViewModel.Cost) {
		updateImportTicketController(with: .promptImport, cost: cost)
    }

	private func showImportSuccessful() {
		updateImportTicketController(with: .succeeded)
		promptBackupWallet()
	}

    private func promptBackupWallet() {
        guard let keystore = try? EtherKeystore(), let address = keystore.recentlyUsedWallet?.address.eip55String else { return }
		let coordinator = PromptBackupCoordinator(walletAddress: address)
		addCoordinator(coordinator)
		coordinator.delegate = self
		coordinator.start()
	}

    private func showImportError(errorMessage: String, cost: ImportTicketViewControllerViewModel.Cost? = nil) {
        updateImportTicketController(with: .failed(errorMessage: errorMessage), cost: cost)
	}

    private func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject) {
        updateImportTicketController(with: .processing)
        delegate?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject) { successful in
            guard let vc = self.importTicketViewController, case .ready = vc.state else { return }
            if successful {
                self.delegate?.didImported(contract: signedOrder.order.contractAddress, in: self)
                self.showImportSuccessful()
            } else {
                //TODO Pass in error message
                self.showImportError(errorMessage: R.string.localizable.aClaimTicketFailedTitle())
            }
        }
    }

	private func importFreeTransfer(query: String, parameters: Parameters) {
		updateImportTicketController(with: .processing)

        Alamofire.request(
                query,
                method: .post,
                parameters: parameters
        ).responseJSON { result in
            var successful = false //need to set this to false by default else it will allow no connections to be considered successful etc
            //401 code will be given if signature is invalid on the server
            if let response = result.response {
                if response.statusCode < 300 {
                    successful = true
                    if let contract = parameters["contractAddress"] as? String {
                        self.delegate?.didImported(contract: contract, in: self)
                    }
                }
            }

            guard let vc = self.importTicketViewController, case .ready(var viewModel) = vc.state else { return }
            // TODO handle http response
            print(result)
            if successful {
                self.showImportSuccessful()
            } else {
                //TODO Pass in error message
                self.showImportError(errorMessage: R.string.localizable.aClaimTicketFailedTitle())
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

extension UniversalLinkCoordinator: ImportTicketViewControllerDelegate {
	func didPressDone(in viewController: ImportTicketViewController) {
		viewController.dismiss(animated: true)
		delegate?.completed(in: self)
	}

	func didPressImport(in viewController: ImportTicketViewController) {
        guard let transactionType = transactionType else { return }
        switch transactionType {
        case .freeTransfer(let query, let parameters):
            importFreeTransfer(query: query, parameters: parameters)
        case .paid(let signedOrder, let tokenObject):
            importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject)
        }
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
