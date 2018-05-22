// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct SettingsViewModel {

    private let isDebug: Bool

    init(
        isDebug: Bool = false
    ) {
        self.isDebug = isDebug
    }

    var servers: [RPCServer] {
        return [
            RPCServer.main,
            RPCServer.classic,
            RPCServer.poa,
            // RPCServer.callisto, TODO: Enable.
            RPCServer.kovan,
            RPCServer.ropsten,
            RPCServer.rinkeby,
            RPCServer.sokol,
        ]
    }

    var currency: [Currency] {
        return Currency.allValues.map { $0 }
    }

    var passcodeTitle: String {
        switch BiometryAuthenticationType.current {
        case .faceID, .touchID:
            return R.string.localizable.settingsBiometricsEnabledLabelTitle(BiometryAuthenticationType.current.title)
        case .none:
            return R.string.localizable.settingsBiometricsDisabledLabelTitle()
        }
    }

    var networkTitle: String {
        return R.string.localizable.settingsNetworkButtonTitle()
    }

    var currencyTitle: String {
        return R.string.localizable.settingsCurrencyButtonTitle()
    }
    
    var localeTitle: String {
        return R.string.localizable.settingsLanguageButtonTitle()
    }
}
