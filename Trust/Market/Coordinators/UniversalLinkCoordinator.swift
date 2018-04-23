// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire
import BigInt
import Realm

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
            "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
        ]
        
        if isForTransfer {
            parameters.removeValue(forKey: "price")
        }
        
        return parameters
    }

    func handlePaidUniversalLink(signedOrder: SignedOrder, ticketHolder: TicketHolder) -> Bool {
        //TODO localize
        if let viewController = delegate?.viewControllerForPresenting(in: self) {
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
            //nil or "" implies free, if using payment server it is always free
            let etherprice = signedOrder.order.price /// 1000000000000000000
            let divideAmount = Decimal(string: "1000000000000000000")!
            let etherPriceDecimal = Decimal(string: etherprice.description)! / divideAmount
            if let price = ethPrice {
                if let s = price.value {
                    let dollarCost = Decimal(s) * etherPriceDecimal
                    self.promptImportUniversalLink(
                            ticketHolder: ticketHolder,
                            ethCost: etherPriceDecimal.description,
                            dollarCost: dollarCost.description
                    )
                }
                else
                {
                    price.subscribe { value in
                        //TODO good to test if there's a leak here if user has already cancelled before this
                        if let s = price.value {
                            let dollarCost = Decimal(s) * etherPriceDecimal
                            self.promptImportUniversalLink(
                                    ticketHolder: ticketHolder,
                                    ethCost: etherPriceDecimal.description,
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
        //TODO localize
        if let viewController = delegate?.viewControllerForPresenting(in: self) {
            UIAlertController.alert(title: nil, message: "Import Link?",
                                    alertButtonTitles: [R.string.localizable.aClaimTicketImportButtonTitle(), R.string.localizable.cancel()],
                                    alertButtonStyles: [.default, .cancel], viewController: viewController) {
                //ok else cancel
                if $0 == 0 {
                    self.importUniversalLink(query: query, parameters: parameters)
                }
            }
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
	func handleUniversalLink(url: URL?) -> Bool {
		let matchedPrefix = (url?.description.contains(UniversalLinkHandler().urlPrefix))!
		guard matchedPrefix else {
			return false
		}

        let signedOrder = UniversalLinkHandler().parseUniversalLink(url: (url?.absoluteString)!)
        getTicketDetailsAndEcRecover(signedOrder: signedOrder) {
            result in
            if let goodResult = result {
                if signedOrder.order.price > 0
                {
                    let success = self.handlePaidUniversalLink(signedOrder: signedOrder, ticketHolder: goodResult)
                }
                else
                {
                    let success = self.usePaymentServerForFreeTransferLinks(
                            signedOrder: signedOrder,
                            ticketHolder: goodResult
                    )
                }
            }
            else {
                self.showImportError(errorMessage: "Invalid Link, please try again")
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
        var indicesStringEncoded = ""
        if !indices.isEmpty {
            for i in 0...indices.count - 1 {
                indicesStringEncoded += String(indices[i]) + ","
            }
            //cut off last comma
            indicesStringEncoded = indicesStringEncoded.substring(to: indicesStringEncoded.count - 1)
        }
        return indicesStringEncoded
    }

    private func getTicketDetailsAndEcRecover(
            signedOrder: SignedOrder,
            completion: @escaping( _ response: TicketHolder?) -> Void
    ) {
        let indices = signedOrder.order.indices
        let parameters = createHTTPParametersForPaymentServer(signedOrder: signedOrder, isForTransfer: false)
        
        Alamofire.request(Constants.getTicketInfoFromServer, method: .get, parameters: parameters).responseJSON {
            response in
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                if let statusCode = response.response?.statusCode
                {
                    if statusCode > 299 {
                        completion(nil)
                        return
                    }
                }
                var array: [String] = utf8Text.split{ $0 == "," }.map(String.init)
                if array.isEmpty || array[0] == "invalid indices" {
                    completion(nil)
                    return
                }
                var bytes32Tickets = [String]()
                //start at one to slice off address
                for i in 1...array.count - 1 {
                    bytes32Tickets.append(array[i])
                }
                
                completion(self.sortTickets(bytes32Tickets, indices))
            }
            else
            {
                completion(nil)
            }
        }
    }
    
    private func sortTickets(_ bytes32Tickets: [String], _ indices: [UInt16]) -> TicketHolder
    {
        var tickets = [Ticket]()
        for i in 0...bytes32Tickets.count - 1 {
            if let tokenId = BigUInt(bytes32Tickets[i], radix: 16) {
                let xmlParsed = XMLHandler().getFifaInfoForToken(tokenId: tokenId)
                let ticket = Ticket(
                    id: bytes32Tickets[i],
                    index: indices[i],
                    zone: xmlParsed.venue,
                    name: "FIFA WC",
                    venue: xmlParsed.locality,
                    date: Date(timeIntervalSince1970: TimeInterval(xmlParsed.time)),
                    seatId: xmlParsed.number,
                    category: xmlParsed.category,
                    countryA: xmlParsed.countryA,
                    countryB: xmlParsed.countryB
                )
                tickets.append(ticket)
            }
        }
        let ticketHolder = TicketHolder(
            tickets: tickets,
            zone: tickets[0].zone,
            name: tickets[0].name,
            venue: tickets[0].venue,
            date: tickets[0].date,
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
		if let vc = importTicketViewController, var viewModel = vc.viewModel {
			viewModel.state = state
            if let ticketHolder = ticketHolder, let ethCost = ethCost, let dollarCost = dollarCost {
				viewModel.ticketHolder = ticketHolder
				viewModel.ethCost = ethCost
				viewModel.dollarCost = dollarCost
			}
			vc.configure(viewModel: viewModel)
		}
	}

	private func promptImportUniversalLink(ticketHolder: TicketHolder, ethCost: String, dollarCost: String) {
		updateImportTicketController(with: .promptImport, ticketHolder: ticketHolder, ethCost: ethCost, dollarCost: dollarCost)
    }

	private func showImportSuccessful() {
		updateImportTicketController(with: .succeeded)
	}

	private func showImportError(errorMessage: String) {
        updateImportTicketController(with: .failed(errorMessage: errorMessage))
	}

    //handling free transfers, sell links cannot be handled here
	private func importUniversalLink(query: String, parameters: Parameters) {
		updateImportTicketController(with: .processing)
        
        Alamofire.request(
                query,
                method: .post,
                parameters: parameters
        ).responseJSON {
            result in
            var successful = false //need to set this to false by default else it will allow no connections to be considered successful etc
            //401 code will be given if signature is invalid on the server
            if let response = result.response {
                if (response.statusCode < 300) {
                    successful = true
                }
            }

            if let vc = self.importTicketViewController {
                // TODO handle http response
                print(result)
                if let vc = self.importTicketViewController, var viewModel = vc.viewModel {
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
