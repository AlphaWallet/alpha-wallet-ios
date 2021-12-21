//
//  ShareContextHandler.swift
//  AlphaWalletShare
//
//  Created by Vladyslav Shepitko on 10.11.2020.
//

import UIKit

@objc(ShareContextHandler)
@available(iOSApplicationExtension, unavailable)
class ShareContextHandler: UIResponder, NSExtensionRequestHandling {

    enum AnyError: Error {
        case canceled
    }

    var extensionContext: NSExtensionContext?

    func beginRequest(with context: NSExtensionContext) {
        self.extensionContext = context

        guard let extensionItem = context.inputItems.first as? NSExtensionItem else {
            context.cancelRequest(withError: AnyError.canceled)
            return
        }

        let valueResolver = DefaultItemProviderValueResolver()
        extensionItem.resolveAttachments(valueResolver: valueResolver) { attachment in
            if let attachment = attachment, let url = attachment.url {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.open(url: url)
                    context.completeRequest(returningItems: nil)
                }
            } else {
                context.cancelRequest(withError: AnyError.canceled)
            }
        }
    }

    private func open(url: URL) {
        guard let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication else { return }

        let selector = NSSelectorFromString("openURL:")

        application.perform(selector, with: url)
    }
}
