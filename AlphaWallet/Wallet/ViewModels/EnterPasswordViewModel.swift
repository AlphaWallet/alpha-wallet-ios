// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct EnterPasswordViewModel {
    var title: String {
        //Have to use the short version otherwise the next screen's back button might be distorted
        return R.string.localizable.enterPasswordNavigationTitleShorter(preferredLanguages: Languages.preferred())
    }

    var headerSectionText: String {
        return R.string.localizable.enterPasswordPasswordHeaderPlaceholder(preferredLanguages: Languages.preferred())
    }

    var passwordFieldPlaceholder: String {
        if ScreenChecker().isNarrowScreen {
            return R.string.localizable.enterPasswordPasswordTextFieldPlaceholderShorter(preferredLanguages: Languages.preferred())
        } else {
            return R.string.localizable.enterPasswordPasswordTextFieldPlaceholder(preferredLanguages: Languages.preferred())
        }
    }
}
