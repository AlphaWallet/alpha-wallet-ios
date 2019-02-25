// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol UniversalLinkInPasteboardCoordinatorDelegate: class {
    func importUniversalLink(url: URL, for coordinator: UniversalLinkInPasteboardCoordinator)
    func showImportError(errorMessage: String, cost: ImportMagicTokenViewControllerViewModel.Cost?)
}

class UniversalLinkInPasteboardCoordinator: Coordinator {
    private let config: Config

    var coordinators: [Coordinator] = []
    weak var delegate: UniversalLinkInPasteboardCoordinatorDelegate?

    init(config: Config) {
        self.config = config
    }
    
    func start() {
        guard let contents = UIPasteboard.general.string?.trimmed else { return }
        guard let url = URL(string: contents) else { return }
        let isLegacy = contents.hasPrefix(Constants.legacyMagicLinkPrefix)
        guard contents.hasPrefix(UniversalLinkHandler(config: config).urlPrefix) || isLegacy else {
            let actualNetwork = config.server.magicLinkNetwork(url: url.description)
            delegate?.showImportError(errorMessage: R.string.localizable.aClaimTokenWrongNetworkLink(actualNetwork), cost: nil)
            return
        }
        UIPasteboard.general.string = ""
        delegate?.importUniversalLink(url: url, for: self)
    }
}
