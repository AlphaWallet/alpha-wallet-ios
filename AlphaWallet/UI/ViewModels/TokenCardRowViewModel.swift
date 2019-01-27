// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TokenCardRowViewModel: TokenCardRowViewModelProtocol {
    let tokenHolder: TokenHolder

    var tokenCount: String {
        return "x\(tokenHolder.tokens.count)"
    }

    var city: String {
        let value = tokenHolder.values["locality"] ?? "N/A"
        return ", \(value)"
    }

    var category: String {
        if tokenHolder.hasAssetDefinition {
            return tokenHolder.values["category"] as? String ?? "N/A"
        } else {
            //For ERC75 tokens, display the contract's name as the "title". https://github.com/alpha-wallet/alpha-wallet-ios/issues/664
            return tokenHolder.name
        }
    }

    var isMeetupContract: Bool {
        return tokenHolder.isSpawnableMeetupContract
    }

    var teams: String {
        if isMeetupContract && tokenHolder.values["expired"] != nil {
            return ""
        } else {
            let countryA = tokenHolder.values["countryA"] as? String ?? ""
            let countryB = tokenHolder.values["countryB"] as? String ?? ""
            return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
        }
    }

    var match: String {
        if tokenHolder.values["section"] != nil {
            if let section = tokenHolder.values["section"] as? Int {
                return "S\(section)"
            } else {
                return "S0"
            }
        } else {
            let value = tokenHolder.values["match"] as? Int ?? 0
            return "M\(value)"
        }
    }

    var venue: String {
        return tokenHolder.values["venue"] as? String ?? "N/A"
    }

    var date: String {
        let value = tokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    var numero: String {
        if let num = tokenHolder.values["numero"] as? Int {
            return String(num)
        } else {
            return "N/A"
        }
    }

    func subscribeExpired(withBlock block: @escaping (String) -> Void) {
        guard isMeetupContract else { return }
        if let subscribableAssetAttributeValue = tokenHolder.values["expired"] as? SubscribableAssetAttributeValue {
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
        if let subscribableAssetAttributeValue = tokenHolder.values["locality"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                if let value = value as? String {
                    block(value)
                }
            }
        }
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if let subscribableAssetAttributeValue = tokenHolder.values["building"] as? SubscribableAssetAttributeValue {
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
        if let subscribableAssetAttributeValue = tokenHolder.values["street"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                if let value = value as? String {
                    updateStreetLocalityStateCountry(
                            street: value,
                            locality: (self.tokenHolder.values["locality"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            state: (self.tokenHolder.values["state"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            country: self.tokenHolder.values["country"] as? String
                    )
                }
            }
        }
        if let subscribableAssetAttributeValue = tokenHolder.values["state"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                if let value = value as? String {
                    updateStreetLocalityStateCountry(
                            street: (self.tokenHolder.values["street"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            locality: (self.tokenHolder.values["locality"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            state: value,
                            country: self.tokenHolder.values["country"] as? String
                    )
                }
            }
        }

        if let subscribableAssetAttributeValue = tokenHolder.values["locality"] as? SubscribableAssetAttributeValue {
            subscribableAssetAttributeValue.subscribable.subscribe { value in
                if let value = value as? String {
                    updateStreetLocalityStateCountry(
                            street: (self.tokenHolder.values["street"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            locality: value,
                            state: (self.tokenHolder.values["state"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                            country: self.tokenHolder.values["country"] as? String
                    )
                }
            }
        }

        if let country = tokenHolder.values["country"] as? String {
            updateStreetLocalityStateCountry(
                    street: (self.tokenHolder.values["street"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                    locality: (self.tokenHolder.values["locality"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                    state: (self.tokenHolder.values["state"] as? SubscribableAssetAttributeValue)?.subscribable.value as? String,
                    country: country
            )
        }
    }

    var time: String {
        let value = tokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.format("h:mm a")
    }

    var onlyShowTitle: Bool {
        return !tokenHolder.hasAssetDefinition
    }
}
