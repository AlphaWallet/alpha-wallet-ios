// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation

struct TransactionsViewModel {
    private static var formatter: DateFormatter {
        return Date.formatter(with: "dd MMM yyyy")
    }
    private var items: [(date: String, transactionRows: [TransactionRow])] = []

    init(transactions: [(date: String, transactionRows: [TransactionRow])] = []) {
        self.items = transactions
    }

    static func mapTransactions(transactions: [TransactionInstance]) -> [(date: String, transactionRows: [TransactionRow])] {
        //Uses NSMutableArray instead of Swift array for performance. Really slow when dealing with 10k events, which is hardly a big wallet
        var newItems: [String: NSMutableArray] = [:]
        for transaction in transactions {
            let date = formatter.string(from: transaction.date)
            let currentItems = newItems[date] ?? .init()
            currentItems.add(transaction)
            newItems[date] = currentItems
        }
        let tuple = newItems.map { each in
            (date: each.key, transactions: (each.value as? [TransactionInstance] ?? []).sorted { $0.date > $1.date })
        }
        let collapsedTransactions: [(date: String, transactions: [TransactionInstance])] = tuple.sorted { (object1, object2) -> Bool in
            guard let d1 = formatter.date(from: object1.date), let d2 = formatter.date(from: object2.date) else {
                return false
            }
            return d1 > d2
        }

        return collapsedTransactions.map { date, transactions in
            var items: [TransactionRow] = .init()
            for each in transactions {
                if each.localizedOperations.isEmpty {
                    items.append(.standalone(each))
                } else if each.localizedOperations.count == 1, each.value == "0" {
                    items.append(.standalone(each))
                } else {
                    items.append(.group(each))
                    items.append(contentsOf: each.localizedOperations.map { .item(transaction: each, operation: $0) })
                }
            }
            return (date: date, transactionRows: items)
        }
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var headerBackgroundColor: UIColor {
        return GroupedTable.Color.background
    }

    var headerTitleTextColor: UIColor {
        return GroupedTable.Color.title
    }

    var headerTitleFont: UIFont {
        return Fonts.tableHeader
    }

    var numberOfSections: Int {
        return items.count
    }

    func numberOfItems(for section: Int) -> Int {
        return items[section].transactionRows.count
    }

    func item(for row: Int, section: Int) -> TransactionRow {
        return items[section].transactionRows[row]
    }

    func titleForHeader(in section: Int) -> String {
        let value = items[section].date
        guard let date = Self.formatter.date(from: value) else { return .init() }
        
        if NSCalendar.current.isDateInToday(date) {
            return R.string.localizable.today().localizedUppercase
        }
        if NSCalendar.current.isDateInYesterday(date) {
            return R.string.localizable.yesterday().localizedUppercase
        }
        return value.localizedUppercase
    }
}
