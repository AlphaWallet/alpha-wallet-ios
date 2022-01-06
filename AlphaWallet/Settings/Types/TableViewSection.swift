//
//  TableViewSection.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit

protocol TableViewSection: class {
    func addMarked(chainID: Int)
    func cellAt(row: Int, from tableView: UITableView) -> UITableViewCell
    func didSelect(row: Int)
    func filter(phrase: String) -> Int
    func headerHeight() -> CGFloat
    func headerView() -> UIView?
    func isEnabled() -> Bool
    func isMarked(chainID: Int) -> Bool
    func removeMarked(chainId: Int)
    func resetFilter() -> Int
    func rows() -> Int
    func selectedServers() -> [CustomRPC]
}
