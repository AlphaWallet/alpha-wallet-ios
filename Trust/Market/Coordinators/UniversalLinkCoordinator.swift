// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire

protocol UniversalLinkCoordinatorDelegate: class {
	func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController?
}

class UniversalLinkCoordinator: Coordinator {
	var coordinators: [Coordinator] = []
	weak var delegate: UniversalLinkCoordinatorDelegate?
	var statusViewController: TicketImportStatusViewController?

	func start() {
	}

	//Returns true if handled
	func handleUniversalLink(url: URL?) -> Bool {
		let matchedPrefix = (url?.description.contains(UniversalLinkHandler().urlPrefix))!
		guard matchedPrefix else {
			return false
		}

		let keystore = try! EtherKeystore()
		let signedOrder = UniversalLinkHandler().parseURL(url: (url?.description)!)
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
			statusViewController = TicketImportStatusViewController()
			if let vc = statusViewController {
				vc.delegate = self
				vc.configure(viewModel: .init(state: .processing))
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
            if(result.response?.statusCode == 401 || result.response!.statusCode > 299) {
                successful = false
            }
			if let vc = self.statusViewController {
				if successful {
					vc.configure(viewModel: .init(state: .succeeded))
				} else {
					vc.configure(viewModel: .init(state: .failed))
				}
			}
		}
	}
}

extension UniversalLinkCoordinator: TicketImportStatusViewControllerDelegate {
	func didPressDone(in viewController: TicketImportStatusViewController) {
		viewController.dismiss(animated: true)
	}
}
