// Copyright DApps Platform Inc. All rights reserved.

import Foundation

public enum DAppError: Error {
    case cancelled
    case nodeError(String)

    public var message: String {
        switch self {
        case .cancelled:
            //This is the default behavior, just keep it
            return "\(self)"
        case .nodeError(let message):
            return message
        }
    }
}
