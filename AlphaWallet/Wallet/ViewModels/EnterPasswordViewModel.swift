// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct EnterPasswordViewModel {
    var title: String {
        if ScreenChecker().isNarrowScreen {
            return R.string.localizable.enterPasswordNavigationTitleShorter()
        } else {
            return R.string.localizable.enterPasswordNavigationTitle()
        }
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
