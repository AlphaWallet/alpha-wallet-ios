// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol UniversalLinkInPasteboardCoordinatorDelegate: class {
    func importUniversalLink(url: URL, for coordinator: UniversalLinkInPasteboardCoordinator)
}

class UniversalLinkInPasteboardCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    weak var delegate: UniversalLinkInPasteboardCoordinatorDelegate?
    
    func start() {
        guard let contents = UIPasteboard.general.string?.trimmed else { return }
        guard contents.hasPrefix(UniversalLinkHandler().urlPrefix) else { return }
        guard contents.count > UniversalLinkHandler().urlPrefix.count else { return }
        guard let url = URL(string: contents) else { return }
        UIPasteboard.general.string = ""
        delegate?.importUniversalLink(url: url, for: self)
    }
}
