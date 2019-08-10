// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

extension TokensViewController {
    class CollectiblesCollectionViewHeader: UICollectionReusableView {
        static let reuseIdentifier = String(describing: CollectiblesCollectionViewHeader.self)

        var filterView: WalletFilterView? {
            didSet {
                guard let filterView = filterView else {
                    if let oldValue = oldValue {
                        oldValue.removeFromSuperview()
                    }
                    return
                }
                filterView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(filterView)

                NSLayoutConstraint.activate([
                    filterView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    filterView.trailingAnchor.constraint(equalTo: trailingAnchor),
                    filterView.topAnchor.constraint(equalTo: topAnchor),
                    filterView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
                ])
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = Colors.appBackground
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

