//
//  SafariWebExtensionHandler.swift
//  AlphaWalletSafariExtension
//
//  Created by Vladyslav Shepitko on 28.09.2021.
//

import os.log
import SafariServices

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "app")
private let SFExtensionMessageKey = "message"

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems[0] as! NSExtensionItem
        let message = item.userInfo?[SFExtensionMessageKey]
        logger.info("Received message from browser.runtime.sendNativeMessage: \(String(describing: message as! CVarArg))")

        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ "Response to": message ] ]

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

}
