// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol UniversalLinkInPasteboardCoordinatorDelegate: AnyObject {
    func importUniversalLink(url: DeepLink, for coordinator: UniversalLinkInPasteboardCoordinator)
}

class UniversalLinkInPasteboardCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    weak var delegate: UniversalLinkInPasteboardCoordinatorDelegate?

    func start() {
        if UIPasteboard.general.hasURLs {
            guard let url = UIPasteboard.general.url else { return }
            guard let deepLink = DeepLink(url: url) else { return }
            UIPasteboard.general.string = ""
            delegate?.importUniversalLink(url: deepLink, for: self)
        }
    }
}
