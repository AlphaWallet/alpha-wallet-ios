// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct ImportMagicTokenCardRowViewModel: TokenCardRowViewModelProtocol {
    var importMagicTokenViewControllerViewModel: ImportMagicTokenViewControllerViewModel

    init(importMagicTokenViewControllerViewModel: ImportMagicTokenViewControllerViewModel) {
        self.importMagicTokenViewControllerViewModel = importMagicTokenViewControllerViewModel
    }

    var tokenCount: String {
        return importMagicTokenViewControllerViewModel.tokenCount
    }

    var city: String {
        return importMagicTokenViewControllerViewModel.city
    }

    var category: String {
        return importMagicTokenViewControllerViewModel.category
    }

    var teams: String {
        return importMagicTokenViewControllerViewModel.teams
    }

    var match: String {
        return importMagicTokenViewControllerViewModel.match
    }

    var venue: String {
        return importMagicTokenViewControllerViewModel.venue
    }

    var date: String {
        return importMagicTokenViewControllerViewModel.date
    }

    var time: String {
        return importMagicTokenViewControllerViewModel.time
    }

    var onlyShowTitle: Bool {
        return importMagicTokenViewControllerViewModel.onlyShowTitle
    }
}
