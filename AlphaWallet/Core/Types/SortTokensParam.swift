//
//  SortTokensParam.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.08.2021.
//

import UIKit

enum SortTokensParam: Int, CaseIterable, DropDownItemType {

    var title: String {
        switch self {
        case .name: return R.string.localizable.sortTokensParamName()
        case .value: return R.string.localizable.sortTokensParamValue()
        case .mostUsed: return R.string.localizable.sortTokensParamMostUsed()
        }
    }

    case name
    case value
    case mostUsed

    static var allCases: [SortTokensParam] {
        return [.name, .value]
    }
}
