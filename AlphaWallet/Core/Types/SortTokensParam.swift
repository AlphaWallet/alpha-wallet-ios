//
//  SortTokensParam.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.08.2021.
//

import Foundation

/// Enum represents value sorting direction
enum SortDirection: Int {
    case ascending
    case descending
}

extension TokenObject {
    /// Helper enum represents fields available for sorting
    enum Field: Int {
        case name
        case value
    }
}

/// Enum represents token objects sorting cases
enum SortTokensParam: CaseIterable {
    case byField(field: TokenObject.Field, direction: SortDirection)
    case mostUsed

    static var allCases: [SortTokensParam] = Constants.defaultSortTokensParams

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.mostUsed, .mostUsed):
            return true
        case (.byField(let field1, let direction1), .byField(let field2, let direction2)):
            return field1 == field2 && direction1 == direction2
        case (.byField, .mostUsed), (.mostUsed, .byField):
            return false
        }
    }
}
