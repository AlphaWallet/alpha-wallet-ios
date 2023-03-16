//
//  SwapError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

public enum SwapError: LocalizedError {
    case unableToBuildSwapUnsignedTransactionFromSwapProvider
    case unableToBuildSwapUnsignedTransaction(message: String)
    case invalidJson
    case userCancelledApproval
    case tokenOrSwapQuoteNotFound
    case inner(Error)
    case unknownError

    init(error: Error) {
        if let e = error as? SwapError {
            self = e
        } else {
            self = .inner(error)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .unableToBuildSwapUnsignedTransaction(let message):
            return "Unable To Build Swap Unsigned Transaction: \(message)"
        case .unableToBuildSwapUnsignedTransactionFromSwapProvider:
            return "Unable To Build Swap Unsigned Transaction From Swap Provider"
        case .userCancelledApproval:
            return "User Cancelled Approval"
        case .unknownError:
            return "Unknown Error"
        case .tokenOrSwapQuoteNotFound:
            return "Unable To Build Swap Unsigned Transaction, Token Or Swap Quote Not Found"
        case .invalidJson:
            return "Invalid Json"
        case .inner(let error):
            return "\(error.localizedDescription)"
        }
    }
}

extension SwapError {
    public var isUserCancelledError: Bool {
        switch self {
        case .userCancelledApproval:
            return true
        case .unableToBuildSwapUnsignedTransactionFromSwapProvider, .unableToBuildSwapUnsignedTransaction, .invalidJson, .tokenOrSwapQuoteNotFound, .unknownError, .inner:
            return false
        }
    }
}

