// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum SettingsError: LocalizedError {
    case failedToSendEmail

    var errorDescription: String? {
        switch self {
        case .failedToSendEmail:
            return R.string.localizable.settingsErrorFailedToSendEmail()
        }
    }
}
