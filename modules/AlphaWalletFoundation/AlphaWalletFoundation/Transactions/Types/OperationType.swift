// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum OperationType: String {
    case nativeCurrencyTokenTransfer
    case erc20TokenTransfer
    case erc20TokenApprove
    case erc721TokenTransfer
    case erc721TokenApproveAll
    case erc875TokenTransfer
    case erc1155TokenTransfer
    case unknown

    public init(string: String) {
        self = OperationType(rawValue: string) ?? .unknown
    }

    public var isTransfer: Bool {
        switch self {
        case .nativeCurrencyTokenTransfer, .erc20TokenTransfer, .erc721TokenTransfer, .erc875TokenTransfer, .erc1155TokenTransfer:
            return true
        case .erc20TokenApprove, .erc721TokenApproveAll:
            return false
        case .unknown:
            return false
        }
    }

    public var isSend: Bool {
        switch self {
        case .nativeCurrencyTokenTransfer, .erc20TokenTransfer, .erc721TokenTransfer, .erc875TokenTransfer, .erc1155TokenTransfer:
            return true
        case .erc20TokenApprove, .erc721TokenApproveAll:
            return false
        case .unknown:
            return false
        }
    }
}

extension OperationType: Decodable { }
