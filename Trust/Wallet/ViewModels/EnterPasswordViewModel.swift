// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct EnterPasswordViewModel {

    var title: String {
        return R.string.localizable.enterPasswordNavigationTitle()
    }

    var headerSectionText: String {
        return R.string.localizable.enterPasswordPasswordHeaderPlaceholder()
    }

    var passwordFieldPlaceholder: String {
        return R.string.localizable.enterPasswordPasswordTextFieldPlaceholder()
    }

    var confirmPasswordFieldPlaceholder: String {
        return R.string.localizable.enterPasswordConfirmPasswordTextFieldPlaceholder()
    }
}
