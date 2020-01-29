// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

extension TokensViewController {
    class CollectiblesCollectionViewHeader: UICollectionReusableView {
        static let reuseIdentifier = String(describing: CollectiblesCollectionViewHeader.self)

        var filterView: SegmentedControl? {
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
                    filterView.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: 0, bottom: 7, right: 0)),
                ])
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = GroupedTable.Color.background
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

