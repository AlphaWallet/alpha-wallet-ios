// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import LocalAuthentication

class LockEnterPasscodeViewModel: LockViewModel {
    let initialLabelText =  R.string.localizable.lockEnterPasscodeViewModelInitial()
    let tryAfterOneMinute =  R.string.localizable.lockEnterPasscodeViewModelTryAfterOneMinute()
    let loginReason = R.string.localizable.lockEnterPasscodeViewModelTouchId()

    private var context: LAContext!
    var canEvaluatePolicy: Bool {
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    func invalidateContext() {
        context = LAContext()
    }

    func evaluatePolicy(completion: @escaping (Bool) -> Void) {
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: loginReason) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
