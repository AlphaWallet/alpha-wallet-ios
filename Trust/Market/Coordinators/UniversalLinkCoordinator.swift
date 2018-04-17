// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire

protocol UniversalLinkCoordinatorDelegate: class {
	func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController?
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject)
	func completed(in coordinator: UniversalLinkCoordinator)
}

//TODO handle the sale link imports
class UniversalLinkCoordinator: Coordinator {
	var coordinators: [Coordinator] = []
	weak var delegate: UniversalLinkCoordinatorDelegate?
	var importTicketViewController: ImportTicketViewController?

	func start() {
		preparingToImportUniversalLink()
	}
    
    func createQueryForPaymentServer(signedOrder: SignedOrder) -> Parameters {
        // form the json string out of the order for the paymaster server
        // James S. wrote
        let keystore = try! EtherKeystore()
        let signature = signedOrder.signature.substring(from: 2)
        let indices = signedOrder.order.indices
        var indicesStringEncoded = ""
        if !indices.isEmpty {
            for i in 0...indices.count - 1 {
                indicesStringEncoded += String(indices[i]) + ","
            }
            //cut off last comma
            indicesStringEncoded = indicesStringEncoded.substring(to: indicesStringEncoded.count - 1)
        } else {
            //this shouldn't happen
            indicesStringEncoded = "0"
        }
        let address = (keystore.recentlyUsedWallet?.address.eip55String)!
        
        let parameters: Parameters = [
            "address": address,
            "indices": indicesStringEncoded,
            "expiry": signedOrder.order.expiry.description,
            "v": signature.substring(from: 128),
            "r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
            "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
        ]
        
        return parameters
    }
    
    func usePaymentServerForFreeTransferLinks(signedOrder: SignedOrder, ticketHolder: TicketHolder) -> Bool {
        let parameters = createQueryForPaymentServer(signedOrder: signedOrder)
        let query = UniversalLinkHandler.paymentServer
        //TODO check if URL is valid or not by validating signature, low priority
        //TODO localize
        if let viewController = delegate?.viewControllerForPresenting(in: self) {
            UIAlertController.alert(title: nil, message: "Import Link?",
                                    alertButtonTitles: [R.string.localizable.aClaimTicketImportButtonTitle(), R.string.localizable.cancel()],
                                    alertButtonStyles: [.default, .cancel], viewController: viewController) {
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
    //TODO handle paying for universal link
	func handleUniversalLink(url: URL?) -> Bool {
		let matchedPrefix = (url?.description.contains(UniversalLinkHandler().urlPrefix))!
		guard matchedPrefix else {
			return false
		}
        let signedOrder = UniversalLinkHandler().parseUniversalLink(url: (url?.absoluteString)!)
        //TODO create Ticket instances and 1 TicketHolder instance and compute cost from link's information
        let ticket = Ticket(id: "0x0000000000000000000000000000000000000000000000000000000000000000", index: 1, zone: "", name: "", venue: "", date: Date(), seatId: 1)
        let ticketHolder = TicketHolder(
            tickets: [ticket],
            zone: "ABC",
            name: "Applying for mortages (APM)",
            venue: "XYZ Stadium",
            date: Date(),
            status: .available
        )
        return usePaymentServerForFreeTransferLinks(signedOrder: signedOrder, ticketHolder: ticketHolder)
	}
    
    //delegate?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject)

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
        }
	}
}
