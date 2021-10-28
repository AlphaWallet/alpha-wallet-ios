//
//  AssetsPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit

typealias TokenAsset = TokenObject

class AssetsPageViewModel {

    private enum AssetsSection: Int, CaseIterable {
        case assets
    }
    
    var navigationTitle: String {
        return R.string.localizable.semifungiblesAssetsTitle()
    }

    var backgroundColor: UIColor {
        GroupedTable.Color.background
    }

    private let tokenHolders: [TokenHolder]
    private let sections: [AssetsSection] = [.assets]

    init(tokenHolders: [TokenHolder]) {
        self.tokenHolders = tokenHolders
    }

    var numberOfSections: Int {
        return sections.count
    }

    func numberOfItems(_ section: Int) -> Int {
        switch sections[safe: section] {
        case .assets:
            return tokenHolders.count
        case .none:
            return 0
        }
    }

    func item(atIndexPath indexPath: IndexPath) -> TokenHolder? {
        switch sections[safe: indexPath.section] {
        case .assets:
            return tokenHolders[safe: indexPath.row]
        case .none:
            return nil
        }
    }
}

