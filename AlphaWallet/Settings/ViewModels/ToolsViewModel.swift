// Copyright © 2022 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class ToolsViewModel {
    private var config: Config
    private var rows: [ToolsViewModel.ToolsRow] = ToolsViewModel.ToolsRow.allCases

    var title: String = R.string.localizable.aSettingsTools()
    var largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode = .never

    init(config: Config) {
        self.config = config
    }

    func numberOfRows() -> Int {
        return rows.count
    }

    func viewModel(for indexPath: IndexPath) -> SettingTableViewCellViewModel {
        let row = rows[indexPath.row]
        return .init(titleText: row.title, subTitleText: nil, icon: row.icon)
    }

    func row(for indexPath: IndexPath) -> ToolsViewModel.ToolsRow {
        return rows[indexPath.row]
    }
}

extension ToolsViewModel {
    enum ToolsRow: Int, CaseIterable {
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
}
