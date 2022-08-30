// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let strongSelf = self else { return nil }
        if strongSelf.isEmpty {
            return nil
        } else {
            return strongSelf
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        if isEmpty {
            return nil
        } else {
            return self
        }
    }
}

extension Optional where Wrapped: Collection {
    var isEmpty: Bool {
        switch self {
        case .none:
            return true
        case .some(let value):
            return value.isEmpty
        }
    }
}
