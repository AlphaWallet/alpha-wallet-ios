//
//  ActivitiesViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import UIKit
import AlphaWalletFoundation

struct ActivitiesViewModel {
    var collection: ActivityCollection

    var backgroundColor: UIColor {
        Colors.appWhite
    }

    var headerBackgroundColor: UIColor {
        GroupedTable.Color.background
    }

    var headerTitleTextColor: UIColor {
        GroupedTable.Color.title
    }

    var headerTitleFont: UIFont {
        Fonts.tableHeader
    }

    var numberOfSections: Int {
        collection.filteredItems.count
    }

    func numberOfItems(for section: Int) -> Int {
        collection.filteredItems[section].items.count
    }

    func item(for row: Int, section: Int) -> ActivityRowModel {
        collection.filteredItems[section].items[row]
    }

    func titleForHeader(in section: Int) -> String {
        let date = collection.filteredItems[section].date.date
        if NSCalendar.current.isDateInToday(date) {
            return R.string.localizable.today().localizedUppercase
        }
        if NSCalendar.current.isDateInYesterday(date) {
            return R.string.localizable.yesterday().localizedUppercase
        }

        return collection.filteredItems[section].date.stringValue.localizedUppercase
    }

    mutating func filter(_ filter: ActivityOrTransactionFilter) {
        collection.filter(filter)
    }
}
