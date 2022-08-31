import Foundation

public enum Dapps {
    public static let masterList: [Dapp] = []

    public struct Category {
        public let name: String
        public var dapps: [Dapp]
    }

    public static let categorisedDapps: [Category] = {
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
