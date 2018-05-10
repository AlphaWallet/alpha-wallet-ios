// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct AdvancedSettingsViewModel {

    var title: String {
        return R.string.localizable.aSettingsAdvancedLabelTitle()
    }

    var showTokensTabTitle: String {
        return R.string.localizable.settingsPreferencesButtonTitle()
    }

    var showTokensTabOnStart: Bool {
        return true
    }

    var networkTitle: String {
        return R.string.localizable.settingsNetworkButtonTitle()
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

    var localeTitle: String {
        return R.string.localizable.settingsLanguageButtonTitle()
    }

    var locales: [AppLocale] {
        return [
            .system,
            .english,
            .simplifiedChinese,
            .spanish,
        ]
    }
}
