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

    var teams: String {
        let countryA = tokenHolder.values["countryA"] as? String ?? ""
        let countryB = tokenHolder.values["countryB"] as? String ?? ""
        return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
    }

    var match: String {
        let value = tokenHolder.values["match"] as? Int ?? 0
        return "M\(value)"
    }

    var venue: String {
        return tokenHolder.values["venue"] as? String ?? "N/A"
    }

    var date: String {
        let value = tokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    //TODO example
//    func subscribeDate(withBlock block: @escaping (String) -> ()) {
//        if let subscribableAssetAttributeValue = tokenHolder.values["expired"] as? SubscribableAssetAttributeValue {
//            subscribableAssetAttributeValue.subscribable.subscribe { value in
//                if let value = value as? Bool {
//                    //TODO: Remove this comment: Cast because of test and type doesn't match only. We know the type here
//                    block("\(value)")
//                }
//            }
//        }
//    }

    var time: String {
        let value = tokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.format("h:mm a")
    }

    var onlyShowTitle: Bool {
        return !tokenHolder.hasAssetDefinition
    }
}
