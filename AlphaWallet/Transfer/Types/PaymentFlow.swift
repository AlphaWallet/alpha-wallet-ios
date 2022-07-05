// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum PaymentFlowType {
    case transaction(TransactionType)
    case tokenScript(action: TokenInstanceAction, token: Token, tokenHolder: TokenHolder)

    var server: RPCServer {
        switch self {
        case .transaction(let transactionType):
            return transactionType.server
        case .tokenScript(_, let token, _):
            return token.server
        }
    }
}

enum PaymentFlow {
    case swap(pair: SwapPair)
    case send(type: PaymentFlowType)
    case request

    var transactionType: TransactionType? {
        switch self {
        case .send(let type):
            switch type {
            case .transaction(let value):
                return value
            case .tokenScript:
                return nil
            }
        case .request, .swap:
            return nil
        }
    }
}
