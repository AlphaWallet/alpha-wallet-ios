//
//  SortTokensParam.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.08.2021.
//

import Foundation

/// Enum represents value sorting direction
public enum SortDirection: Int {
    case ascending
    case descending
}

public extension Token {
    /// Helper enum represents fields available for sorting
    enum Field: Int {
        case name
        case value
    }
}

/// Enum represents token objects sorting cases
public enum SortTokensParam: CaseIterable, Equatable {
    case byField(field: Token.Field, direction: SortDirection)
    case mostUsed

    public static var allCases: [SortTokensParam] = Constants.defaultSortTokensParams
}
