// Copyright SIX DAY LLC. All rights reserved.

import Foundation

class LockCreatePasscodeViewModel: LockViewModel {
    let title = R.string.localizable.lockCreatePasscodeViewModelTitle()
    let initialLabelText = R.string.localizable.lockCreatePasscodeViewModelInitial()
    let confirmLabelText = R.string.localizable.lockCreatePasscodeViewModelConfirm()
    
    private (set) var firstPasscode: String?

    func set(firstPasscode: String?) {
        self.firstPasscode = firstPasscode
    } 
}
