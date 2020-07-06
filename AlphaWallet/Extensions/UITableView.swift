//
//  UITableView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.07.2020.
//

import UIKit

protocol WithReusableIdentifier {
    static var reusableIdentifier: String { get }
}

extension WithReusableIdentifier {
    static var reusableIdentifier: String {
        String(describing: self)
    }
}

extension UITableViewCell: WithReusableIdentifier {
}

extension UITableViewHeaderFooterView: WithReusableIdentifier {
}

extension UICollectionViewCell: WithReusableIdentifier {
}

extension UICollectionReusableView: WithReusableIdentifier {
}

extension UITableView {

    func registerHeaderFooterView(_ reusable: UITableViewHeaderFooterView.Type) {
        register(reusable.self, forHeaderFooterViewReuseIdentifier: reusable.reusableIdentifier)
    }

    func register(_ reusable: UITableViewCell.Type) {
        register(reusable.self, forCellReuseIdentifier: reusable.reusableIdentifier)
    }

    func dequeueReusableCell<T>(for indexPath: IndexPath) -> T where T: WithReusableIdentifier {
        return dequeueReusableCell(withIdentifier: T.reusableIdentifier, for: indexPath) as! T
    }

    func dequeueReusableHeaderFooterView<T>() -> T where T: WithReusableIdentifier {
        return dequeueReusableHeaderFooterView(withIdentifier: T.reusableIdentifier) as! T
    }
}

extension UICollectionView {

    func registerSupplementaryView(_ reusable: UICollectionReusableView.Type, of elementKind: String) {
        register(reusable.self, forSupplementaryViewOfKind: elementKind, withReuseIdentifier: reusable.reusableIdentifier)
    }

    func register(_ reusable: UICollectionViewCell.Type) {

        register(reusable.self, forCellWithReuseIdentifier: reusable.reusableIdentifier)
    }

    func dequeueReusableCell<T>(for indexPath: IndexPath) -> T where T: WithReusableIdentifier {
        return dequeueReusableCell(withReuseIdentifier: T.reusableIdentifier, for: indexPath) as! T
    }

    func dequeueReusableSupplementaryView<T>(ofKind elementKind: String, for indexPath: IndexPath) -> T where T: WithReusableIdentifier {
        dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: T.reusableIdentifier, for: indexPath) as! T
    }
}
