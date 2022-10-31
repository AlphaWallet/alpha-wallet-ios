//
//  ExpandableSection.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import UIKit

protocol ExpandableSection: AnyObject {
    var openedSections: Set<Int> { get set }

    func expandOrCollapseAction(for section: Int) -> TransactionConfirmationViewModel.ExpandOrCollapseAction
}

extension ExpandableSection {
    func expandOrCollapseAction(for section: Int) -> TransactionConfirmationViewModel.ExpandOrCollapseAction {
        if !openedSections.contains(section) {
            openedSections.insert(section)

            return .expand
        } else {
            openedSections.remove(section)

            return .collapse
        }
    }
}
