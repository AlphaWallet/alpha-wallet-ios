// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct ImportMagicTokenCardRowViewModel: TokenCardRowViewModelProtocol {
    private var importMagicTokenViewControllerViewModel: ImportMagicTokenViewControllerViewModel

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

    var numero: String {
        return importMagicTokenViewControllerViewModel.numero
    }

    var time: String {
        return importMagicTokenViewControllerViewModel.time
    }

    var onlyShowTitle: Bool {
        return importMagicTokenViewControllerViewModel.onlyShowTitle
    }

    var isMeetupContract: Bool {
        return importMagicTokenViewControllerViewModel.tokenHolder?.isSpawnableMeetupContract ?? false
    }

    func subscribeExpired(withBlock block: @escaping (String) -> Void) {
        guard isMeetupContract else { return }
        if let subscribableAssetAttributeValue = importMagicTokenViewControllerViewModel.tokenHolder?.values["expired"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                if let expired = value as? Bool {
                    if expired {
                        block("Expired")
                    } else {
                        block("Not expired")
                    }
                }
            }
        }
    }

    func subscribeLocality(withBlock block: @escaping (String) -> Void) {
        guard isMeetupContract else { return }
        if let subscribableAssetAttributeValue = importMagicTokenViewControllerViewModel.tokenHolder?.values["locality"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                if let value = value as? String {
                    block(value)
                }
            }
        }
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if let subscribableAssetAttributeValue = importMagicTokenViewControllerViewModel.tokenHolder?.values["building"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                if let value = value as? String {
                    block(value)
                }
            }
        }
    }

    func subscribeStreetLocalityStateCountry(withBlock block: @escaping (String) -> Void) {
        func updateStreetLocalityStateCountry(street: String?, locality: String?, state: String?, country: String?) {
            let values = [street, locality, state, country].compactMap { $0 }
            let string = values.joined(separator: ", ")
            block(string)
        }
        if let subscribableAssetAttributeValue = importMagicTokenViewControllerViewModel.tokenHolder?.values["street"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewControllerViewModel.tokenHolder else { return }
                if let value = value as? String {
                    updateStreetLocalityStateCountry(
                            street: value,
                            locality: (tokenHolder.values["locality"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            state: (tokenHolder.values["state"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            country: tokenHolder.values["country"] as? String
                    )
                }
            }
        }
        if let subscribableAssetAttributeValue = importMagicTokenViewControllerViewModel.tokenHolder?.values["state"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewControllerViewModel.tokenHolder else { return }
                if let value = value as? String {
                    updateStreetLocalityStateCountry(
                            street: (tokenHolder.values["street"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            locality: (tokenHolder.values["locality"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            state: value,
                            country: tokenHolder.values["country"] as? String
                    )
                }
            }
        }
        if let subscribableAssetAttributeValue = importMagicTokenViewControllerViewModel.tokenHolder?.values["locality"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewControllerViewModel.tokenHolder else { return }
                if let value = value as? String {
                    updateStreetLocalityStateCountry(
                            street: (tokenHolder.values["street"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            locality: value,
                            state: (tokenHolder.values["state"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            country: tokenHolder.values["country"] as? String
                    )
                }
            }
        }
        if let country = importMagicTokenViewControllerViewModel.tokenHolder?.values["country"] as? String {
            guard let tokenHolder = self.importMagicTokenViewControllerViewModel.tokenHolder else { return }
            updateStreetLocalityStateCountry(
                    street: (tokenHolder.values["street"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                    locality: (tokenHolder.values["locality"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                    state: (tokenHolder.values["state"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                    country: country
            )
        }
    }
}
