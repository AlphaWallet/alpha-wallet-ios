// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum InCoordinatorError: LocalizedError {
    case onlyWatchAccount

    var errorDescription: String? {
        return R.string.localizable.inCoordinatorErrorOnlyWatchAccount()
    }
}
