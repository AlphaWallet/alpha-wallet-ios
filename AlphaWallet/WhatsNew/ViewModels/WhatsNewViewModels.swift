//
//  WhatsNewViewModels.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 29/11/21.
//

import Foundation

class WhatsNewListingViewModel: NSObject {
    let model: WhatsNewListing
    let title: String
    let entries: [WhatsNewEntryViewModel]
    let shouldShowCheckmarks: Bool

    init(model: WhatsNewListing, title: String, shouldShowCheckmarks: Bool) {
        self.model = model
        self.title = title
        self.entries = functional.generateEntries(fromModel: model)
        self.shouldShowCheckmarks = shouldShowCheckmarks
        super.init()
    }
}

extension WhatsNewListingViewModel {
    fileprivate class functional {
        static func generateEntries(fromModel model: WhatsNewListing) -> [WhatsNewEntryViewModel] {
            return model.listing.map { model in
                WhatsNewEntryViewModel(model: model)
            }
        }
    }
}

class WhatsNewEntryViewModel: NSObject {
    let model: WhatsNew
    var title: String {
        return model.title
    }
    var changes: [String] {
        return model.changes
    }

    init(model: WhatsNew) {
        self.model = model
        super.init()
    }
}