// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct PreferencesViewModel {

    var title: String {
        return R.string.localizable.settingsPreferencesTitle()
    }

    var showTokensTabTitle: String {
        return R.string.localizable.settingsPreferencesButtonTitle()
    }

    var showTokensTabOnStart: Bool {
        return true
    }
}
