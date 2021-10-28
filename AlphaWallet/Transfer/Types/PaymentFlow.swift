// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum PaymentFlowType {
    case transaction(TransactionType)
    case tokenScript(action: TokenInstanceAction, tokenObject: TokenObject, tokenHolder: TokenHolder)

    var server: RPCServer {
        switch self {
        case .transaction(let transactionType):
            return transactionType.server
        case .tokenScript(_, let tokenObject, _):
            return tokenObject.server
        }
    }
}

enum PaymentFlow {
    case send(type: PaymentFlowType)
    case request
}
