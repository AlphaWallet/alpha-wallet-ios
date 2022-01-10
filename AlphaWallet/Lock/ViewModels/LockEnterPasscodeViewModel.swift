// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class LockEnterPasscodeViewModel: LockViewModel {
    let initialLabelText =  R.string.localizable.lockEnterPasscodeViewModelInitial(preferredLanguages: Languages.preferred())
    let tryAfterOneMinute =  R.string.localizable.lockEnterPasscodeViewModelTryAfterOneMinute(preferredLanguages: Languages.preferred())
    let loginReason = R.string.localizable.lockEnterPasscodeViewModelTouchId(preferredLanguages: Languages.preferred())
}
