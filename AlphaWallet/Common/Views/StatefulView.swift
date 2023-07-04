//
//  StatefulView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import StatefulViewController

protocol StatefulSubView: UIView {
    func hasContent() -> Bool
}

extension UITableView: StatefulSubView {
    func hasContent() -> Bool {
        if numberOfSections > 0 {
            let rows = (0 ..< numberOfSections).reduce(0, { sum, i in
                var sum = sum
                sum += numberOfRows(inSection: i)

                return sum
            })
            return rows > 0
        } else {
            return false
        }
    }
}

class StatefulView<T: StatefulSubView>: UIView {
    private var subview: T

    init(subview: T) {
        self.subview = subview
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
        NSLayoutConstraint.activate([subview.anchorsConstraintSafeArea(to: self)])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func resetStatefulStateToReleaseObjectToAvoidMemoryLeak() {
        // NOTE: Stateful lib set to object state machine that later causes ref cycle when applying it to view
        // here we release all associated objects to release state machine
        // this method is called while parent's view deinit get called
        objc_removeAssociatedObjects(self)
    }
}

extension StatefulView: StatefulViewController {
    func hasContent() -> Bool {
        return subview.hasContent()
    }
}
