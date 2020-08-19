// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

extension TokensViewController {
    class CollectiblesCollectionViewHeader: UICollectionReusableView {
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
                    filterView.anchorsConstraint(to: self, edgeInsets: .zero),
                ])
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = GroupedTable.Color.background
        }

        required init?(coder aDecoder: NSCoder) {
            return nil
        }
    }
}

