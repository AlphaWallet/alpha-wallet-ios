//
//  TransactionConfirmationRPCServerInfoView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.11.2021.
//

import UIKit
import AlphaWalletFoundation

class TransactionConfirmationRPCServerInfoView: UIView {

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 16 : 18)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Colors.darkGray

        return titleLabel
    }()

    private let serverIconImageView: RoundedImageView = {
        let imageView = RoundedImageView(size: .init(width: 20, height: 20))
        return imageView
    }()

    init(viewModel: TransactionConfirmationRPCServerInfoViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            serverIconImageView,
            titleLabel
        ].asStackView(axis: .horizontal, spacing: 10)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isLayoutMarginsRelativeArrangement = true

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: Screen.TransactionConfirmation.transactionRowInfoInsets),
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configure(viewModel: TransactionConfirmationRPCServerInfoViewModel) {
        titleLabel.text = viewModel.title
        serverIconImageView.subscribable = viewModel.iconImage
    }
}

struct TransactionConfirmationRPCServerInfoViewModel {
    let title: String
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
        self.title = server.name
    }

    var iconImage: Subscribable<Image> {
        server.walletConnectIconImage
    }
}
