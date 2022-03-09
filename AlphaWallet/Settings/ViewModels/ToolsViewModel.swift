// Copyright © 2022 Stormbird PTE. LTD.

import UIKit

struct ToolsViewModel {
    var rows: [ToolsRow] = {
        return [
            .console,
            .pingInfura,
            .checkTransactionState
        ]
    }()

    func numberOfRows() -> Int {
        return rows.count
    }
}

enum ToolsRow: CaseIterable {
    case console
    case pingInfura
    case checkTransactionState
    var title: String {
        switch self {
        case .console:
            return R.string.localizable.aConsoleTitle()
        case .pingInfura:
            return R.string.localizable.settingsPingInfuraTitle()
        case .checkTransactionState:
            return R.string.localizable.settingsCheckTransactionState()
        }
    }

    var icon: UIImage {
        switch self {
        case .console:
            return R.image.settings_console()!
        case .pingInfura:
            //TODO need a more appropriate icon, maybe represent diagnostic or (to a lesser degree Infura)
            return R.image.settings_analytics()!
        case .checkTransactionState:
            //TODO need a more appropriate icon, maybe represent diagnostic or (to a lesser degree Infura)
            return R.image.settings_analytics()!
        }
    }
}
