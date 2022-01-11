// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenViewControllerHeaderViewDelegate: AnyObject {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, inHeaderView: TokenViewControllerHeaderView)
    func didShowHideMarketPrice(inHeaderView: TokenViewControllerHeaderView)
}

class TokenViewControllerHeaderView: UIView {
    private let contract: AlphaWallet.Address
    private let recentTransactionsLabel = UILabel()
    private let recentTransactionsLabelBorders = (top: UIView(), bottom: UIView())
    private let spacers = (beforeTokenScriptFileStatus: UIView.spacer(height: DataEntry.Metric.SendHeader.topSpacerHeight), ())

    let sendHeaderView = SendHeaderView()
    weak var delegate: TokenViewControllerHeaderViewDelegate?

    init(contract: AlphaWallet.Address) {
        self.contract = contract
        super.init(frame: .zero)

        sendHeaderView.delegate = self

        let recentTransactionsLabelHolder = UIView()
        recentTransactionsLabelHolder.backgroundColor = GroupedTable.Color.background
        recentTransactionsLabel.translatesAutoresizingMaskIntoConstraints = false
        recentTransactionsLabelHolder.addSubview(recentTransactionsLabel)

        let stackView = [
            spacers.beforeTokenScriptFileStatus,
            sendHeaderView,
            recentTransactionsLabelBorders.top,
            recentTransactionsLabelHolder,
            recentTransactionsLabelBorders.bottom,
            .spacer(height: 7),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            recentTransactionsLabelBorders.top.heightAnchor.constraint(equalToConstant: 1),
            recentTransactionsLabelBorders.bottom.heightAnchor.constraint(equalToConstant: 1),

            recentTransactionsLabelHolder.heightAnchor.constraint(equalToConstant: DataEntry.Metric.SendHeader.RecentTransactionsLabel.height),
            recentTransactionsLabel.anchorsConstraint(to: recentTransactionsLabelHolder, edgeInsets: DataEntry.Metric.SendHeader.RecentTransactionsLabel.edgeInsets),

            stackView.anchorsConstraint(to: self),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configure() {
        recentTransactionsLabel.textColor = .init(red: 118, green: 118, blue: 118)
        recentTransactionsLabel.font = Fonts.semibold(size: 15)
        recentTransactionsLabel.text = R.string.localizable.recentTransactions(preferredLanguages: Languages.preferred())

        recentTransactionsLabelBorders.top.backgroundColor = UIColor(red: 236, green: 236, blue: 236)
        recentTransactionsLabelBorders.bottom.backgroundColor = UIColor(red: 236, green: 236, blue: 236)
    }
}

extension TokenViewControllerHeaderView: SendHeaderViewDelegate {
    func didPressViewContractWebPage(inHeaderView: SendHeaderView) {
        delegate?.didPressViewContractWebPage(forContract: contract, inHeaderView: self)
    }

    func showHideMarketPriceSelected(inHeaderView: SendHeaderView) {
        delegate?.didShowHideMarketPrice(inHeaderView: self)
    }
}
