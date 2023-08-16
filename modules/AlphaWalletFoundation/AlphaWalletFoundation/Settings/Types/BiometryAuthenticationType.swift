// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication

public enum BiometryAuthenticationType {
    case touchID
    case faceID
    case none

    public static var current: BiometryAuthenticationType {
        // https://stackoverflow.com/a/46920111
        let authContext = LAContext()
        let _ = authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch authContext.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        @unknown default:
            //TODO For Xcode 15's .opticID and anything in the future
            return none
        }
    }
}
