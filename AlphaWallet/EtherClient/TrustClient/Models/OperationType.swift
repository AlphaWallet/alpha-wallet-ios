// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum OperationType: String {
    case nativeCurrencyTokenTransfer
    case erc20TokenTransfer
    case erc721TokenTransfer
    case erc875TokenTransfer
    case unknown

    init(string: String) {
        self = OperationType(rawValue: string) ?? .unknown
    }
}

extension OperationType: Decodable { }
