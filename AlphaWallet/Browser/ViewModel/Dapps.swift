// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

enum Dapps {
    static let masterList = [
        Dapp(name: "AirSwap", description: "Peer-to-Peer trading on Ethereum", url: "https://airswap.io", cat: "Games"),
        Dapp(name: "Chibi Fighters", description: "Chibi Fighters are fierce little warriors that know no mercy", url: "https://chibifighters.io", cat: "Games"),
        Dapp(name: "CryptoKitties", description: "Collect and breed digital cats!", url: "https://cryptokitties.co", cat: "Misc"),
        Dapp(name: "Multitoken Protocol", description: "Protect Crypto Investments from Volatility", url: "https://multitoken.com", cat: "Misc"),
    ]

    struct Category {
        let name: String
        var dapps: [Dapp]
    }

    static let categorisedDapps: [Category] = {
        var results = [String: Category]()
        for each in masterList {
            let catName = each.cat
            if var cat = results[catName] {
                var dapps = cat.dapps
                dapps.append(each)
                cat.dapps = dapps
                results[catName] = cat
            } else {
                var cat = Category(name: catName, dapps: [each])
                results[catName] = cat
            }
        }
        return results.values.sorted { $0.name < $1.name }
    }()
}
