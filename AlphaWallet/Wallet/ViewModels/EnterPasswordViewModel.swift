// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct EnterPasswordViewModel {
    var title: String {
        //Have to use the short version otherwise the next screen's back button might be distorted
        return R.string.localizable.enterPasswordNavigationTitleShorter()
    }

    var headerSectionText: String {
        return R.string.localizable.enterPasswordPasswordHeaderPlaceholder()
    }

    var passwordFieldPlaceholder: String {
        if ScreenChecker().isNarrowScreen {
            return R.string.localizable.enterPasswordPasswordTextFieldPlaceholderShorter()
        } else {
            return R.string.localizable.enterPasswordPasswordTextFieldPlaceholder()
        }
    }
}
