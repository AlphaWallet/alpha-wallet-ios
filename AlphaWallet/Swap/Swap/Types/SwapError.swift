//
//  SwapError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

enum SwapError: Error {
    case unableToBuildSwapUnsignedTransactionFromSwapProvider
    case userCancelledApproval
    case approveTransactionNotCompleted
    case tokenOrSwapQuoteNotFound
    case unknownError

    var localizedDescription: String {
        switch self {
        case .unableToBuildSwapUnsignedTransactionFromSwapProvider:
            return "Unable To Build Swap Unsigned Transaction From Swap Provider"
        case .userCancelledApproval:
            return "User Cancelled Approval"
        case .approveTransactionNotCompleted:
            return "Approve Transaction Not Completed"
        case .unknownError:
            return "Unknown Error"
        case .tokenOrSwapQuoteNotFound:
            return "Unable To Build Swap Unsigned Transaction, Token Or Swap Quote Not Found"
        }
    }
}
