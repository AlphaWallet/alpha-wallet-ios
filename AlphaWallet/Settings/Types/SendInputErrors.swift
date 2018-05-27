// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum SendInputErrors: LocalizedError {
    case emptyClipBoard
    case wrongInput

    var errorDescription: String? {
        switch self {
        case .emptyClipBoard:
            return R.string.localizable.sendErrorEmptyClipBoard()
        case .wrongInput:
            return R.string.localizable.sendErrorWrongInput()
        }
    }
}
