//
//  TableViewDiffableDataSource.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.07.2022.
//

import UIKit
import Combine

// swiftlint:disable generic_type_name
class TableViewDiffableDataSource<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable>: UITableViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType> {
// swiftlint:enable generic_type_name
    let numberOfRowsInSection: PassthroughSubject<Int, Never> = .init()

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        numberOfRowsInSection.send(section)
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
}
