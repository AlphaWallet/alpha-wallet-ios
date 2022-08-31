//
//  TokenSwapperLoadingState.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

extension TokenSwapper {
    public enum LoadingState: Equatable {
        case pending
        case updating
        case failure(error: TokenSwapper.TokenSwapperError)
        case done

        public static func == (lhs: TokenSwapper.LoadingState, rhs: TokenSwapper.LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.pending, .pending), (.updating, .updating), (.done, .done):
                return true
            case (.failure(let e1), .failure(let e2)):
                return e1 == e2
            default:
                return false
            }
        }
    }
}
