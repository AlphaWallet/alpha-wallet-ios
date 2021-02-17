// Copyright DApps Platform Inc. All rights reserved.

import Foundation

enum DAppError: Error {
    case cancelled
    case nodeError(String)

    var message: String {
        switch self {
        case .cancelled:
            //This is the default behavior, just keep it
            return "\(self)"
        case .nodeError(let message):
            return message
        }
    }
}
