//
//  SectionProtocol.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.06.2022.
//

import UIKit

protocol SectionProtocol: AnyObject {
    var openedSections: Set<Int> { get set }

    func showHideSection(_ section: Int) -> TransactionConfirmationViewModel.Action
}

extension SectionProtocol {
    func showHideSection(_ section: Int) -> TransactionConfirmationViewModel.Action {
        if !openedSections.contains(section) {
            openedSections.insert(section)

            return .show
        } else {
            openedSections.remove(section)

            return .hide
        }
    }
}
