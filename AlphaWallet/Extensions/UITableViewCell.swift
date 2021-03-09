//
//  UITableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.03.2021.
//

import UIKit

extension UITableViewCell {

    var tableView: UITableView? {
        return next(UITableView.self)
    }

    var indexPath: IndexPath? {
        return tableView?.indexPath(for: self)
    }

}

extension UICollectionViewCell {

    var collectionView: UICollectionView? {
        return next(UICollectionView.self)
    }

    var indexPath: IndexPath? {
        return collectionView?.indexPath(for: self)
    }
}
