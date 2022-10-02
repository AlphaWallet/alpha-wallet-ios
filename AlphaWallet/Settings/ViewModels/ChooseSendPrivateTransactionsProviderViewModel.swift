// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

class ChooseSendPrivateTransactionsProviderViewModel {
    private var config: Config
    let title: String = R.string.localizable.settingsChooseSendPrivateTransactionsProviderButtonTitle()
    let largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode = .never

    init(config: Config) {
        self.config = config
    }

    var rows: [SendPrivateTransactionsProvider] = [
        .ethermine,
        .eden,
    ]

    var numberOfRows: Int {
        rows.count
    }

    func viewModel(for indexPath: IndexPath) -> SwitchTableViewCellViewModel {
        let row = rows[indexPath.row]
        return .init(titleText: row.title, icon: row.icon, value: config.sendPrivateTransactionsProvider == row)
    }

    func selectProvider(at indexPath: IndexPath) {
        let provider = rows[indexPath.row]
        let chosenProvider: SendPrivateTransactionsProvider?
        if provider == config.sendPrivateTransactionsProvider {
            chosenProvider = nil
        } else {
            chosenProvider = provider
        }
        config.sendPrivateTransactionsProvider = chosenProvider
    }
}
