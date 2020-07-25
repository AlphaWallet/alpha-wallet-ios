// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

extension TokensViewController {
    class FilterTokensCollectionHeaderView: UICollectionReusableView {
        var filterView: SegmentedControl? {
            didSet {
                guard let filterView = filterView else {
                    if let oldValue = oldValue {
                        oldValue.removeFromSuperview()
                    }
                    return
                }

                filterView.backgroundColor = Colors.appWhite
                filterView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(filterView)

                NSLayoutConstraint.activate([
                    filterView.anchorsConstraint(to: self)
                ])
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = Colors.appWhite
        }

        required init?(coder aDecoder: NSCoder) {
            return nil
        }
    }
}

