// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct SettingsViewModel {
    private let isDebug: Bool

    init(
        isDebug: Bool = false
    ) {
        self.isDebug = isDebug
    }

    var passcodeTitle: String {
        switch BiometryAuthenticationType.current {
        case .faceID, .touchID:
            return R.string.localizable.settingsBiometricsEnabledLabelTitle(BiometryAuthenticationType.current.title)
        case .none:
            return R.string.localizable.settingsBiometricsDisabledLabelTitle()
        }
    }

    var localeTitle: String {
        return R.string.localizable.settingsLanguageButtonTitle()
    }
}
