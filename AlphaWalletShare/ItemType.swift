//
//  ItemType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation
import Social
import MobileCoreServices

extension NSItemProvider {
    enum ItemType {
        case url
        case text
        case unknown

        init(_ value: NSItemProvider) {
            if value.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                self = .url
            } else if value.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                self = .text
            } else {
                self = .unknown
            }
        }

        var rawValue: String {
            switch self {
            case .url:
                return kUTTypeURL as String
            case .text:
                return kUTTypeText as String
            case .unknown:
                return String()
            }
        }
    }

    var type: ItemType {
        return ItemType(self)
    }
}
