// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

public protocol UniversalLinkInPasteboardServiceDelegate: AnyObject {
    func importUniversalLink(url: DeepLink, for service: UniversalLinkInPasteboardService)
}

public class UniversalLinkInPasteboardService {
    public weak var delegate: UniversalLinkInPasteboardServiceDelegate?

    public init() { }
    public func start() {
        if UIPasteboard.general.hasURLs {
            guard let url = UIPasteboard.general.url else { return }
            guard let deepLink = DeepLink(url: url) else { return }
            UIPasteboard.general.string = ""
            delegate?.importUniversalLink(url: deepLink, for: self)
        }
    }
}
