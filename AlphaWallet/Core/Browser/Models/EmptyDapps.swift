import Foundation

enum Dapps {
    static let masterList: [Dapp] = []

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
