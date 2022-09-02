//
//  TableViewSection.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit
import AlphaWalletFoundation

protocol TableViewSection: class {
    func addMarked(chainID: Int)
    func serverAt(row: Int) -> CustomRPC
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
