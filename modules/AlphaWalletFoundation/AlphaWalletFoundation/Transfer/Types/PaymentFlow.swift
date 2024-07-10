// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum PaymentFlowType {
    case transaction(TransactionType)

    public var server: RPCServer {
        switch self {
        case .transaction(let transactionType):
            return transactionType.server
        }
    }
}

public enum SwapTokenFlow {
    case swapToken(token: Token)
    case selectTokenToSwap
}

public enum PaymentFlow {
    case swap(pair: SwapPair)
    case send(type: PaymentFlowType)
    case request

    public var transactionType: TransactionType? {
        switch self {
        case .send(let type):
            switch type {
            case .transaction(let value):
                return value
            }
        case .request, .swap:
            return nil
        }
    }
}

public enum UncompletedPaymentFlow {
    /// when user need to select token to send to recipient
    case sendToRecipient(recipient: AddressOrDomainName)
}

public enum SuggestedPaymentFlow {
    case payment(type: PaymentFlow, server: RPCServer)
    case other(value: UncompletedPaymentFlow)
}
