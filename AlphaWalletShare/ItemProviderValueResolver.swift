//
//  ItemProviderValueResolver.swift
//  AlphaWalletShare
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation
import Social
import MobileCoreServices
import AlphaWalletFoundation

protocol ItemProviderValueResolver {
    var supportedTypes: [NSItemProvider.ItemType] { get }

    func resolve(itemType: NSItemProvider.ItemType, value: NSSecureCoding?) -> ShareContentAction?
}

class DefaultItemProviderValueResolver: ItemProviderValueResolver {

    var supportedTypes: [NSItemProvider.ItemType] {
        return [.url]
    }

    func resolve(itemType: NSItemProvider.ItemType, value: NSSecureCoding?) -> ShareContentAction? {
        return ShareContentAction(itemType: itemType, value: value)
    }
}

extension ShareContentAction {

    init?(itemType: NSItemProvider.ItemType, value: NSSecureCoding?) {
        switch itemType {
        case .url:
            guard let v = value as? URL else { return nil }

            self = .url(v)
        case .text:
            guard let v = value as? String else { return nil }

            self = .string(v)
        case .unknown:
            return nil
        }
    }
}

extension NSExtensionItem {

    func resolveAttachments(valueResolver: ItemProviderValueResolver, completion: @escaping (ShareContentAction?) -> Void) {
        guard let attachment = attachments?.first, valueResolver.supportedTypes.contains(attachment.type) else {
            completion(.none)
            return
        }

        attachment.loadItem(forTypeIdentifier: attachment.type.rawValue, options: nil) { result, _ in
            let value = valueResolver.resolve(itemType: attachment.type, value: result)
            
            DispatchQueue.main.async {
                completion(value)
            }
        }
    }
}
