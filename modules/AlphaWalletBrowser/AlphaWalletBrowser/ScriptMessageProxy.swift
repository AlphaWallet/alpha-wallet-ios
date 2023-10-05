// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import WebKit

///Reason for this class: https://stackoverflow.com/questions/26383031/wkwebview-causes-my-view-controller-to-leak
public final class ScriptMessageProxy: NSObject, WKScriptMessageHandler {

    private weak var delegate: WKScriptMessageHandler?

    public init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
