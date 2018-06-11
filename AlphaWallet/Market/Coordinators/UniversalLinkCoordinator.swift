// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import BigInt
import Realm
import TrustKeystore

protocol UniversalLinkCoordinatorDelegate: class {
	func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController?
	func completed(in coordinator: UniversalLinkCoordinator)
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void)
}

class UniversalLinkCoordinator: Coordinator {
	var coordinators: [Coordinator] = []
	weak var delegate: UniversalLinkCoordinatorDelegate?
	var importTicketViewController: ImportTicketViewController?
    var ethPrice: Subscribable<Double>?
    var ethBalance: Subscribable<BigInt>?
    var hasCompleted = false
    var addressOfNewWallet: String?

	func start() {
		preparingToImportUniversalLink()
	}
    
    func createHTTPParametersForPaymentServer(signedOrder: SignedOrder, isForTransfer: Bool) -> Parameters {
        // form the json string out of the order for the paymaster server
        // James S. wrote
        let keystore = try! EtherKeystore()
        let signature = signedOrder.signature.substring(from: 2)
        let indices = signedOrder.order.indices
        let indicesStringEncoded = stringEncodeIndices(indices)
        let address = (keystore.recentlyUsedWallet?.address.eip55String)!
        var parameters: Parameters = [
            "address": address,
            "indices": indicesStringEncoded,
            "price": signedOrder.order.price.description,
            "expiry": signedOrder.order.expiry.description,
            "v": signature.substring(from: 128),
            "r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
            "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128))),
            "networkId": Config().chainID.description
        ]
        
        if isForTransfer {
            parameters.removeValue(forKey: "price")
        }
        
        return parameters
    }

    func handlePaidUniversalLink(signedOrder: SignedOrder, ticketHolder: TicketHolder) -> Bool {
        //TODO localize
        //TODO improve. Not an obvious link between the variables used in the if-statement and the body
        if delegate?.viewControllerForPresenting(in: self) != nil {
            if let vc = importTicketViewController {
                vc.signedOrder = signedOrder
                vc.tokenObject = TokenObject(contract: signedOrder.order.contractAddress,
                                                name: Constants.event,
                                                symbol: "FIFA",
                                                decimals: 0,
                                                value: signedOrder.order.price.description,
                                                isCustom: true,
                                                isDisabled: false,
                                                isStormBird: true
                )
            }
            if let price = ethPrice {
                let ethCost = self.convert(ethCost: signedOrder.order.price)
                self.promptImportUniversalLink(
                        ticketHolder: ticketHolder,
                        ethCost: ethCost.description
                )
                price.subscribe { [weak self] value in
                    if let price = price.value {
                        if let celf = self {
                            let (ethCost, dollarCost) = celf.convert(ethCost: signedOrder.order.price, rate: price)
                            celf.promptImportUniversalLink(
                                    ticketHolder: ticketHolder,
                                    ethCost: ethCost.description,
                                    dollarCost: dollarCost.description
                            )
                        }
                    }
                }
            } else {
                //No wallet and should be handled by client code, but we'll just be careful
                //TODO pass in error message
                showImportError(errorMessage: R.string.localizable.aClaimTicketFailedTitle())
            }
        }
        return true
    }

    func usePaymentServerForFreeTransferLinks(signedOrder: SignedOrder, ticketHolder: TicketHolder) -> Bool {
        let parameters = createHTTPParametersForPaymentServer(signedOrder: signedOrder, isForTransfer: true)
        let query = Constants.paymentServer
        //TODO improve. Not an obvious link between the variables used in the if-statement and the body
        if delegate?.viewControllerForPresenting(in: self) != nil {
            if let vc = importTicketViewController {
                vc.query = query
                vc.parameters = parameters
            }
            //nil or "" implies free, if using payment server it is always free
            self.promptImportUniversalLink(
                    ticketHolder: ticketHolder,
                    ethCost: "",
                    dollarCost: ""
            )
        }
        return true
    }

	//Returns true if handled
    
	func handleUniversalLink(url: URL) -> Bool {
		let matchedPrefix = url.description.contains(UniversalLinkHandler().urlPrefix)
		guard matchedPrefix else {
			return false
		}
        let signedOrder = UniversalLinkHandler().parseUniversalLink(url: url.absoluteString)
        let xmlAddress = XMLHandler().getAddressFromXML(server: RPCServer(chainID: Config().chainID))
        let isStormBirdContract = xmlAddress.eip55String == signedOrder.order.contractAddress
        getTicketDetailsAndEcRecover(signedOrder: signedOrder) { result in
            if let goodResult = result {
                //user can pay gas for free import links if they are not covered by our server
                if signedOrder.order.price > 0 || !isStormBirdContract {
                    if let balance = self.ethBalance {
                        balance.subscribeOnce { value in
                            if value > signedOrder.order.price {
                                let _ = self.handlePaidUniversalLink(signedOrder: signedOrder, ticketHolder: goodResult)
                            } else {
                                if let price = self.ethPrice {
                                    if price.value == nil {
                                        let ethCost = self.convert(ethCost: signedOrder.order.price)
                                        self.showImportError(errorMessage: R.string.localizable.aClaimTicketFailedNotEnoughEthTitle(), ticketHolder: goodResult, ethCost: ethCost.description)
                                    }
                                    price.subscribe { [weak self] value in
                                        if let celf = self {
                                            if let price = price.value {
                                                let (ethCost, dollarCost) = celf.convert(ethCost: signedOrder.order.price, rate: price)
                                                celf.showImportError(errorMessage: R.string.localizable.aClaimTicketFailedNotEnoughEthTitle(), ticketHolder: goodResult, ethCost: ethCost.description, dollarCost: dollarCost.description)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                else {
                    let _ = self.usePaymentServerForFreeTransferLinks(
                            signedOrder: signedOrder,
                            ticketHolder: goodResult
                    )
                }
            } else {
                self.showImportError(errorMessage: R.string.localizable.aClaimTicketInvalidLinkTryAgain())
            }

        }
        return true
	}

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject) {
        updateImportTicketController(with: .processing)
        delegate?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject) { successful in
            if self.importTicketViewController != nil {
                if let vc = self.importTicketViewController, var _ = vc.viewModel {
                    if successful {
                        self.showImportSuccessful()
                    } else {
                        //TODO Pass in error message
                        self.showImportError(errorMessage: R.string.localizable.aClaimTicketFailedTitle())
                    }
                }
            }
        }

    }

    private func stringEncodeIndices(_ indices: [UInt16]) -> String {
        return indices.map(String.init).joined(separator: ",")
    }

    private func getTicketDetailsAndEcRecover(
            signedOrder: SignedOrder,
            completion: @escaping( _ response: TicketHolder?) -> Void
    ) {
        let indices = signedOrder.order.indices
        let parameters = createHTTPParametersForPaymentServer(signedOrder: signedOrder, isForTransfer: false)
        
        Alamofire.request(Constants.getTicketInfoFromServer, method: .get, parameters: parameters).responseJSON { response in
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                if let statusCode = response.response?.statusCode {
                    if statusCode > 299 {
                        completion(nil)
                        return
                    }
                }
                var array = utf8Text.split(separator: ",").map(String.init)
                if array.isEmpty || array[0] == "invalid indices" {
                    completion(nil)
                    return
                }
                //start at one to slice off address
                let bytes32Tickets = Array(array[1...])
                completion(self.sortTickets(bytes32Tickets, indices))
            } else {
                completion(nil)
            }
        }
    }
    
    private func sortTickets(_ bytes32Tickets: [String], _ indices: [UInt16]) -> TicketHolder {
        var tickets = [Ticket]()
        let xmlHandler = XMLHandler()
        for i in 0...bytes32Tickets.count - 1 {
            let ticket = bytes32Tickets[i]
            if let tokenId = BigUInt(ticket, radix: 16) {
                let ticket = xmlHandler.getFifaInfoForTicket(tokenId: tokenId, index: UInt16(i))
                tickets.append(ticket)
            }
        }
        let ticketHolder = TicketHolder(
            tickets: tickets,
            status: .available
        )
        return ticketHolder
    }

	private func preparingToImportUniversalLink() {
		if let viewController = delegate?.viewControllerForPresenting(in: self) {
			importTicketViewController = ImportTicketViewController()
			if let vc = importTicketViewController {
				vc.delegate = self
				vc.configure(viewModel: .init(state: .validating))
				viewController.present(UINavigationController(rootViewController: vc), animated: true)
			}
		}
	}

	private func updateImportTicketController(with state: ImportTicketViewControllerViewModel.State, ticketHolder: TicketHolder? = nil, ethCost: String? = nil, dollarCost: String? = nil) {
        guard !hasCompleted else { return }
		if let vc = importTicketViewController, var viewModel = vc.viewModel {
			viewModel.state = state
            if let ticketHolder = ticketHolder {
                viewModel.ticketHolder = ticketHolder
            }
            if let ethCost = ethCost {
                viewModel.ethCost = ethCost
            }
            if let dollarCost = dollarCost {
                viewModel.dollarCost = dollarCost
            }
			vc.configure(viewModel: viewModel)
		}
        hasCompleted = state.hasCompleted
	}

	private func promptImportUniversalLink(ticketHolder: TicketHolder, ethCost: String, dollarCost: String? = nil) {
		updateImportTicketController(with: .promptImport, ticketHolder: ticketHolder, ethCost: ethCost, dollarCost: dollarCost)
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

    private func showImportError(errorMessage: String, ticketHolder: TicketHolder? = nil, ethCost: String? = nil, dollarCost: String? = nil) {
        updateImportTicketController(with: .failed(errorMessage: errorMessage), ticketHolder: ticketHolder, ethCost: ethCost, dollarCost: dollarCost)
	}

    //handling free transfers, sell links cannot be handled here
	private func importUniversalLink(query: String, parameters: Parameters) {
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
                }
            }

            //TODO improve. Not an obvious link between the variables used in the if-statement and the body
            if let vc = self.importTicketViewController, vc.viewModel != nil {
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
        if let query = viewController.query, let parameters = viewController.parameters {
            importUniversalLink(query: query, parameters: parameters)
        } else {
            if let signedOrder = viewController.signedOrder, let tokenObj = viewController.tokenObject {
                importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObj)
            }
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
