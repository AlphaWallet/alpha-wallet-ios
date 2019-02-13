// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol UniversalLinkInPasteboardCoordinatorDelegate: class {
    func importUniversalLink(url: URL, for coordinator: UniversalLinkInPasteboardCoordinator)
    func showImportError(errorMessage: String, cost: ImportMagicTokenViewControllerViewModel.Cost?)
}

class UniversalLinkInPasteboardCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    weak var delegate: UniversalLinkInPasteboardCoordinatorDelegate?
    
    func start() {
        guard let contents = UIPasteboard.general.string?.trimmed else { return }
        guard let url = URL(string: contents) else { return }
        let isLegacy = contents.hasPrefix(Constants.legacyMagicLinkPrefix)
        guard contents.hasPrefix(UniversalLinkHandler().urlPrefix) || isLegacy else {
            let actualNetwork = Config().server.magicLinkNetwork(url: url.description)
            delegate?.showImportError(errorMessage: R.string.localizable.aClaimTokenWrongNetworkLink(actualNetwork), cost: nil)
            return
        }
        UIPasteboard.general.string = ""
        delegate?.importUniversalLink(url: url, for: self)
    }
}
