//
//  TokenSwapperError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

extension TokenSwapper {
    //TODO: Fix error equatability
    public enum TokenSwapperError: Equatable, Error, CustomStringConvertible {
        public static func == (lhs: TokenSwapper.TokenSwapperError, rhs: TokenSwapper.TokenSwapperError) -> Bool {
            switch (lhs, rhs) {
            case (.sessionsEmpty, .sessionsEmpty), (.networkConnectionMissing, .networkConnectionMissing), (.fromTokenNotFound, .fromTokenNotFound):
                return true
            case (.swapPairNotFound, .swapPairNotFound):
                return true
            case (.general, .general):
                return true
            default:
                return false
            }
        }

        case sessionsEmpty
        case networkConnectionMissing
        case fromTokenNotFound
        case swapPairNotFound
        case general(error: Error)

        public var description: String {
            switch self {
            case .sessionsEmpty:
                return "Sessions Empty"
            case .networkConnectionMissing:
                return "Internet Connection Missing"
            case .fromTokenNotFound:
                return "Token not found. Make sure you have added token"
            case .swapPairNotFound:
                return "Swap Pair Not Found"
            case .general(let e):
                if let error = e as? SwapError {
                    return error.localizedDescription
                } else {
                    return e.localizedDescription
                }
            }
        }
    }
}
