//
//  SelfResizableCollectionView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.01.2022.
//

import UIKit

class SelfResizableCollectionView: UICollectionView {
    private var heightConstant: NSLayoutConstraint!
    private var contentSizeObservation: NSKeyValueObservation!

    override init(frame: CGRect, collectionViewLayout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: collectionViewLayout)
        translatesAutoresizingMaskIntoConstraints = false

        heightConstant = heightAnchor.constraint(greaterThanOrEqualToConstant: 1)
        heightConstant.priority = UILayoutPriority(999)
        heightConstant.isActive = true
        
        setContentHuggingPriority(.required, for: .vertical)

        contentSizeObservation = observe(\.contentSize, options: [.initial, .new]) { [weak self] cv, _ in
            guard let strongSelf = self, cv.contentSize != .zero else { return }

            strongSelf.heightConstant.constant = cv.contentSize.height
        }
    }

    override func reloadData() {
        super.reloadData()
        collectionViewLayout.invalidateLayout()
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
