//
//  UICollectionViewLayout+Extensions.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit

extension UICollectionViewLayout {
    static func createGridLayout(contentInsets: NSDirectionalEdgeInsets = .init(top: 16, leading: 16, bottom: 0, trailing: 16), spacing: CGFloat = 16, heightDimension: CGFloat = 220, colums: Int = 2) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
            let iosVersionRelatedFractionalWidthForGrid: CGFloat = 1.0

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(iosVersionRelatedFractionalWidthForGrid), heightDimension: .absolute(heightDimension))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: colums)
            group.interItemSpacing = .fixed(spacing)
            group.contentInsets = contentInsets

            return NSCollectionLayoutSection(group: group)
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        layout.configuration = config

        return layout
    }

    static func createListLayout(spacing: CGFloat = 16, heightDimension: CGFloat = 96) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(heightDimension))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.contentInsets = .zero

            return NSCollectionLayoutSection(group: group)
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        layout.configuration = config

        return layout
    }
}
