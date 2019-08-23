// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

extension TokensViewController {
    class TableViewHeader: UIView {
        let consoleButton: UIButton
        let promptBackupWalletViewHolder: UIView

        init(consoleButton: UIButton, promptBackupWalletViewHolder: UIView) {
            self.consoleButton = consoleButton
            self.promptBackupWalletViewHolder = promptBackupWalletViewHolder
            super.init(frame: .zero)

            consoleButton.isHidden = true
            promptBackupWalletViewHolder.isHidden = true

            let stackView = [
                consoleButton,
                promptBackupWalletViewHolder
            ].asStackView(axis: .vertical)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.anchorsConstraint(to: self),
            ])
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
