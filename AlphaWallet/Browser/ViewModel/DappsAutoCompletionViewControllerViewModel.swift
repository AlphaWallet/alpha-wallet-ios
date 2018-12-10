// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct DappsAutoCompletionViewControllerViewModel {
    var dappSuggestions = [Dapp]()

    var dappSuggestionsCount: Int {
        return dappSuggestions.count
    }

    var keyword: String = "" {
        didSet {
            let lowercased = keyword.lowercased().trimmed
            dappSuggestions = Dapps.masterList.filter { $0.name.lowercased().contains(lowercased) || $0.url.lowercased().contains(lowercased) }
        }
    }
}
