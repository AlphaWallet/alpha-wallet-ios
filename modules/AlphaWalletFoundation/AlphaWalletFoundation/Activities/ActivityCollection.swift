// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletTokenScript

public enum ActivityOrTransactionFilter {
    case keyword(_ value: String?)
}
extension ActivityOrTransactionFilter: Equatable {
    public static func == (lhs: ActivityOrTransactionFilter, rhs: ActivityOrTransactionFilter) -> Bool {
        switch (lhs, rhs) {
        case (.keyword(let k1), .keyword(let k2)):
            return k1 == k2
        }
    }
}

public struct ActivityCollection {
    static var formatter: DateFormatter = Date.formatter(with: "dd MMM yyyy")
    public struct ActivityDateKey: Hashable, Equatable {
        public let date: Date
        public let stringValue: String

        public init(date: Date) {
            self.date = date

            stringValue = ActivityCollection.formatter.string(from: date)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(stringValue)
        }

        public static func == (_ lhs: ActivityDateKey, _ rhs: ActivityDateKey) -> Bool {
            return lhs.stringValue == rhs.stringValue
        }
    }

    public typealias MappedToDateActivityOrTransaction = (date: ActivityDateKey, items: [ActivityRowModel])

    private var items: [MappedToDateActivityOrTransaction] = []
    public private (set) var filteredItems: [MappedToDateActivityOrTransaction] = []

    public var itemsCount: Int {
        items.count
    }

    public init(activities: [MappedToDateActivityOrTransaction] = []) {
        items = activities
    }

    // swiftlint:disable function_body_length
    static func sorted(activities: [ActivityRowModel]) -> [MappedToDateActivityOrTransaction] {
        //Uses NSMutableArray instead of Swift array for performance. Really slow when dealing with 10k events, which is hardly a big wallet
        var newItems: [ActivityDateKey: NSMutableArray] = [:]

        for each in activities {
            let key: ActivityDateKey = .init(date: each.date)
            let currentItems = newItems[key, default: .init()]
            currentItems.add(each)

            newItems[key] = currentItems
        }

        return newItems.map { each in
            (date: each.key, items: (each.value as! [ActivityRowModel]).sorted {
                //Show pending transactions at the top
                if $0.blockNumber == 0 && $1.blockNumber != 0 {
                    return true
                } else if $0.blockNumber != 0 && $1.blockNumber == 0 {
                    return false
                } else if $0.blockNumber > $1.blockNumber {
                    return true
                } else if $0.blockNumber < $1.blockNumber {
                    return false
                } else {
                    if $0.transactionIndex > $1.transactionIndex {
                        return true
                    } else if $0.transactionIndex < $1.transactionIndex {
                        return false
                    } else {
                        switch ($0, $1) {
                        case (.parentTransaction(transaction: let t0, _, _), .parentTransaction(transaction: let t1, _, _)):
                            return t0.blockNumber > t1.blockNumber
                        case (.parentTransaction, _):
                            return true
                        case (_, .parentTransaction):
                            return false
                        case let (.standaloneActivity(a0), .standaloneActivity(a1)):
                            return a0.logIndex > a1.logIndex
                        case let (.childTransaction(t0, _, _), .childTransaction(t1, _, _)):
                            if let n0 = Int(t0.nonce), let n1 = Int(t1.nonce) {
                                return n0 > n1
                            } else {
                                return false
                            }
                        case (.childTransaction, .standaloneActivity):
                            return false
                        case (.standaloneActivity, .childTransaction):
                            return true
                        case (.childTransaction, .standaloneTransaction):
                            return false
                        case (.standaloneTransaction, .childTransaction):
                            return true
                        case (.standaloneTransaction, .standaloneActivity):
                            return true
                        case (.standaloneActivity, .standaloneTransaction):
                            return false
                        case (.childActivity(transaction: let t0, activity: let a0), .childActivity(transaction: let t1, activity: let a1)):
                            if t0.blockNumber > t1.blockNumber {
                                return true
                            }
                            if t1.blockNumber > t0.blockNumber {
                                return false
                            }
                            return a0.logIndex > a1.logIndex
                        case (.childActivity(transaction: let t0, _), .childTransaction(transaction: let t1, _, _)):
                            if t0.blockNumber > t1.blockNumber {
                                return true
                            }
                            if t1.blockNumber > t0.blockNumber {
                                return false
                            }
                            return true
                        case (.childActivity(transaction: let t0, _), .standaloneTransaction(transaction: let t1, _)):
                            return t0.blockNumber > t1.blockNumber
                        case (.childActivity(transaction: let t0, _), .standaloneActivity(activity: let a1)):
                            return t0.blockNumber > a1.blockNumber
                        case (.standaloneTransaction(transaction: let t0, _), .childActivity(transaction: let t1, _)):
                            return t0.blockNumber > t1.blockNumber
                        case (.standaloneTransaction(transaction: let t0, _), .standaloneTransaction(transaction: let t1, _)):
                            return t0.blockNumber > t1.blockNumber
                        case (.childTransaction(transaction: let t0, _, _), .childActivity(transaction: let t1, _)):
                            if t0.blockNumber > t1.blockNumber {
                                return true
                            }
                            if t1.blockNumber > t0.blockNumber {
                                return false
                            }
                            return true
                        case (.standaloneActivity(activity: let a0), .childActivity(transaction: let transaction, _)):
                            return a0.blockNumber > transaction.blockNumber
                        }
                    }
                }
            })
        }
        .sorted { (object1, object2) -> Bool in
            return object1.date.date.timeIntervalSince1970 > object2.date.date.timeIntervalSince1970
        }
    }
    // swiftlint:enable function_body_length

    public mutating func filter(_ filter: ActivityOrTransactionFilter) {
        var newFilteredItems = items

        switch filter {
        case .keyword(let keyword):
            if let valueToSearch = keyword?.trimmed.lowercased(), valueToSearch.nonEmpty {
                let twoKeywords = splitIntoExactlyTwoKeywords(valueToSearch)
                let results = newFilteredItems.compactMap { date, content -> MappedToDateActivityOrTransaction? in
                    let data: [ActivityRowModel]
                    if let twoKeywords = twoKeywords {
                        //Special case to support keywords like "Sent CoFi"
                        data = content.filter { data -> Bool in
                            (data.activityName?.lowercased().contains(twoKeywords.0) ?? false) &&
                                    (data.getTokenSymbol()?.lowercased().contains(twoKeywords.1) ?? false)
                        }
                    } else {
                        data = content.filter { data -> Bool in
                            (data.activityName?.lowercased().contains(valueToSearch) ?? false) ||
                                    (data.getTokenSymbol()?.lowercased().contains(valueToSearch) ?? false)
                        }
                    }

                    if data.isEmpty {
                        return nil
                    } else {
                        return (date: date, items: data)
                    }
                }

                newFilteredItems = results
            }
        }

        filteredItems = newFilteredItems
    }

    private func splitIntoExactlyTwoKeywords(_ string: String) -> (String, String)? {
        let components = string.split(separator: " ")
        guard components.count == 2 else { return nil }
        return (String(components[0]), String(components[1]))
    }
}

extension String {
    public var nonEmpty: Bool {
        return !self.trimmed.isEmpty
    }
}
