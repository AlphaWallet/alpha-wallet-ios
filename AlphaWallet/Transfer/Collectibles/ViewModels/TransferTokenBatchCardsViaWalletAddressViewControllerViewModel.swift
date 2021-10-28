//
//  TransferTokenBatchCardsViaWalletAddressViewControllerViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

struct TransferTokenBatchCardsViaWalletAddressViewControllerViewModel {
    let token: TokenObject
    let tokenHolders: [TokenHolder]
    let assetDefinitionStore: AssetDefinitionStore
    var availableAmountInt: Int {
        Int(tokenHolders[0].values.valueIntValue ?? 0)
    }
    var selectedAmount: Int {
        tokenHolders[0].selectedCount(tokenId: tokenHolders[0].tokenId) ?? 0
    }
    lazy var selectionViewModel: SelectTokenCardAmountViewModel = .init(availableAmount: availableAmountInt, selectedAmount: selectedAmount)
    
    var navigationTitle: String {
        R.string.localizable.send()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var targetAddressAttributedString: NSAttributedString {
        return .init(string: R.string.localizable.aSendRecipientAddressTitle(), attributes: [
            .font: Fonts.regular(size: 13),
            .foregroundColor: R.color.dove()!
        ])
    }

    var isAmountSelectionHidden: Bool {
        tokenHolders.count > 1
    }

    func updateSelectedAmount(_ value: Int) {
        //NOTE: safety check
        guard tokenHolders.count == 1 else { return }
        tokenHolders[0].select(with: .token(tokenId: tokenHolders[0].tokenId, amount: value))
    }
}
