// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication

enum BiometryAuthenticationType {
    case touchID
    case faceID
    case none

    var title: String {
        switch self {
        case .faceID: return R.string.localizable.faceId()
        case .touchID: return R.string.localizable.touchId()
        case .none: return ""
        }
    }

    static var current: BiometryAuthenticationType {
        // https://stackoverflow.com/a/46920111
        let authContext = LAContext()
        if #available(iOS 11, *) {
            let _ = authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            switch authContext.biometryType {
            case .none:
                return .none
            case .touchID:
                return .touchID
            case .faceID:
                return .faceID
            }
        } else {
            return authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? .touchID : .none
        }
    }
}
