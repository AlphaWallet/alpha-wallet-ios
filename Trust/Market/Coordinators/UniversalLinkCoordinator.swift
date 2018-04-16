// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire

protocol UniversalLinkCoordinatorDelegate: class {
	func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController?
    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject)
}

class UniversalLinkCoordinator: Coordinator {
	var coordinators: [Coordinator] = []
	weak var delegate: UniversalLinkCoordinatorDelegate?
	var statusViewController: StatusViewController?

	func start() {
	}
    
    func usePaymentServerForFreeTransferLinks(signedOrder: SignedOrder) -> Bool {
        // form the json string out of the order for the paymaster server
        // James S. wrote
        let keystore = try! EtherKeystore()
        let signature = signedOrder.signature.substring(from: 2)
        let indices = signedOrder.order.indices
        var indicesStringEncoded = ""
        
        for i in 0...indices.count - 1 {
            indicesStringEncoded += String(indices[i]) + ","
        }
        //cut off last comma
        indicesStringEncoded = indicesStringEncoded.substring(to: indicesStringEncoded.count - 1)
        let address = (keystore.recentlyUsedWallet?.address.eip55String)!
        
        let parameters: Parameters = [
            "address": address,
            "indices": indicesStringEncoded,
            "expiry": signedOrder.order.expiry.description,
            "v": signature.substring(from: 128),
            "r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
            "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
        ]
        let query = UniversalLinkHandler.paymentServer
        
        //TODO check if URL is valid or not by validating signature, low priority
        //TODO localize
        if signature.count > 128 {
            if let viewController = delegate?.viewControllerForPresenting(in: self) {
                UIAlertController.alert(title: nil, message: "Import Link?",
                                        alertButtonTitles: [R.string.localizable.aClaimTicketImportButtonTitle(), R.string.localizable.cancel()],
                                        alertButtonStyles: [.default, .cancel], viewController: viewController) {
                    if $0 == 0 {
                        self.importUniversalLink(query: query, parameters: parameters)
                    }
                }
            }
        } else {
            return true
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
        if(signedOrder.order.price > 0) {
            return handlePaidUniversalLink(signedOrder: signedOrder)
        } else {
            return usePaymentServerForFreeTransferLinks(signedOrder: signedOrder)
        }
	}
    
    //TODO handle claim order flow here
    //delegate from app coordinator 
    func handlePaidUniversalLink(signedOrder: SignedOrder) -> Bool {
        let keystore = try! EtherKeystore()
        let tokenObject = TokenObject(
            contract: signedOrder.order.contractAddress,
            name: "FIFA WC Tickets",
            symbol: "FIFA",
            decimals: 0,
            value: "0",
            isCustom: true,
            isDisabled: false,
            isStormBird: true
        )
        let wallet = keystore.recentlyUsedWallet!
        delegate?.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject)
        return true
    }

	private func importUniversalLink(query: String, parameters: Parameters) {
		if let viewController = delegate?.viewControllerForPresenting(in: self) {
			statusViewController = StatusViewController()
			if let vc = statusViewController {
				vc.delegate = self
				vc.configure(viewModel: .init(
						state: .processing,
						inProgressText: R.string.localizable.aClaimTicketInProgressTitle(),
						succeededTextText: R.string.localizable.aClaimTicketSuccessTitle(),
						failedText: R.string.localizable.aClaimTicketFailedTitle()
				))
				vc.modalPresentationStyle = .overCurrentContext
				viewController.present(vc, animated: true)
			}
		}

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
            
            if let vc = self.statusViewController {
                // TODO handle http response
                print(result)
                if let vc = self.statusViewController, var viewModel = vc.viewModel {
                    if successful {
                        viewModel.state = .succeeded
                        vc.configure(viewModel: viewModel)
                    } else {
                        viewModel.state = .failed
                        vc.configure(viewModel: viewModel)
                    }
                }
            }
        }
    }
}


extension UniversalLinkCoordinator: StatusViewControllerDelegate {
	func didPressDone(in viewController: StatusViewController) {
		viewController.dismiss(animated: true)
	}
}
