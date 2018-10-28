// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct TransactionsViewModel {
    private var formatter: DateFormatter {
        return Date.formatter(with: "dd MMM yyyy")
    }
    private var items: [(date: String, transactions: [Transaction])] = []
    private let config: Config

    init(
        transactions: [Transaction] = [],
        config: Config = Config()
    ) {
        self.config = config

        var newItems: [String: [Transaction]] = [:]

        for transaction in transactions {
            let date = formatter.string(from: transaction.date)

            var currentItems = newItems[date] ?? []
            currentItems.append(transaction)
            newItems[date] = currentItems
        }
        //TODO. IMPROVE perfomance
        let tuple = newItems.map { (key, values) in return (date: key, transactions: values) }
        items = tuple.sorted { (object1, object2) -> Bool in
            return formatter.date(from: object1.date)! > formatter.date(from: object2.date)!
        }
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var headerBackgroundColor: UIColor {
        return Colors.appBackground
    }

    var headerTitleTextColor: UIColor {
        return Colors.appWhite
    }

    var headerTitleFont: UIFont {
        return Fonts.regular(size: 16)!
    }

    var numberOfSections: Int {
        return items.count
    }

    func numberOfItems(for section: Int) -> Int {
        return items[section].transactions.count
    }

    func item(for row: Int, section: Int) -> Transaction {
        return items[section].transactions[row]
    }

    func titleForHeader(in section: Int) -> String {
        let value = items[section].date
        let date = formatter.date(from: value)!
        if NSCalendar.current.isDateInToday(date) {
            return R.string.localizable.today()
        }
        if NSCalendar.current.isDateInYesterday(date) {
            return R.string.localizable.yesterday()
        }
        return value
    }
}
