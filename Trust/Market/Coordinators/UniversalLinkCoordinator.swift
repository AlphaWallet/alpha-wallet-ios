// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire

protocol UniversalLinkCoordinatorDelegate: class {
	func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController?
}

class UniversalLinkCoordinator: Coordinator {
	var coordinators: [Coordinator] = []
	weak var delegate: UniversalLinkCoordinatorDelegate?
	var statusViewController: StatusViewController?

	func start() {
	}

	//Returns true if handled
	func handleUniversalLink(url: URL?) -> Bool {
		let matchedPrefix = (url?.description.contains(UniversalLinkHandler().urlPrefix))!
		guard matchedPrefix else {
			return false
		}
		let keystore = try! EtherKeystore()
        let signedOrder = UniversalLinkHandler().parseUniversalLink(url: (url?.absoluteString)!)
		let signature = signedOrder.signature.substring(from: 2)

		// form the json string out of the order for the paymaster server
		// James S. wrote
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
			"v": signature.substring(from: 128),
			"r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
			"s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
		]
        let query = UniversalLinkHandler.paymentServer

		//TODO check if URL is valid or not by validating signature, low priority
        //TODO localize
		if signature.count > 128 {
			if let viewController = delegate?.viewControllerForPresenting(in: self) {
				UIAlertController.alert(title: nil, message: "Import Link?", alertButtonTitles: [R.string.localizable.aClaimTicketImportButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: viewController) {
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
            var successful = true
            //401 code will be given if signature is invalid on the server
            if let response = result.response, (response.statusCode == 401 || response.statusCode > 299) {
                successful = false
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
