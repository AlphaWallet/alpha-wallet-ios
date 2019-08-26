// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol GenerateTransferMagicLinkViewControllerDelegate: class {
    func didPressShare(in viewController: GenerateTransferMagicLinkViewController, sender: UIView)
    func didPressCancel(in viewController: GenerateTransferMagicLinkViewController)
}

class GenerateTransferMagicLinkViewController: UIViewController {
    private let background = UIView()
	private let header = TokensCardViewControllerTitleHeader()
    private let detailsBackground = UIView()
    private let subtitleLabel = UILabel()
    private let tokenCountLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let actionButton = UIButton()
    private let cancelButton = UIButton()
    private var viewModel: GenerateTransferMagicLinkViewControllerViewModel?

    let paymentFlow: PaymentFlow
    let tokenHolder: TokenHolder
    let linkExpiryDate: Date
    weak var delegate: GenerateTransferMagicLinkViewControllerDelegate?

    init(paymentFlow: PaymentFlow, tokenHolder: TokenHolder, linkExpiryDate: Date) {
        self.paymentFlow = paymentFlow
        self.tokenHolder = tokenHolder
        self.linkExpiryDate = linkExpiryDate
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .clear

        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(visualEffectView, at: 0)

        view.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        tokenCountLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        detailsBackground.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(detailsBackground)

        actionButton.addTarget(self, action: #selector(share), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let stackView = [
            header,
            .spacer(height: 20),
            subtitleLabel,
            tokenCountLabel,
            .spacer(height: 20),
            descriptionLabel,
            .spacer(height: 30),
            actionButton,
            .spacer(height: 10),
            cancelButton,
            .spacer(height: 1)
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 60),
            //Strange repositioning of header horizontally while typing without this
            header.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),

            visualEffectView.anchorsConstraint(to: view),

            detailsBackground.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            detailsBackground.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            detailsBackground.topAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -12),
            detailsBackground.bottomAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),

            actionButton.heightAnchor.constraint(equalToConstant: 47),
            cancelButton.heightAnchor.constraint(equalTo: actionButton.heightAnchor),

            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 16, left: 40, bottom: 16, right: 40)),

            background.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 42),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
            background.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: GenerateTransferMagicLinkViewControllerViewModel) {
        self.viewModel = viewModel
        if let viewModel = self.viewModel {
            background.backgroundColor = viewModel.contentsBackgroundColor
            background.layer.cornerRadius = Metrics.CornerRadius.popups

            header.configure(title: viewModel.headerTitle)

            subtitleLabel.numberOfLines = 0
            subtitleLabel.textColor = viewModel.subtitleColor
            subtitleLabel.font = viewModel.subtitleFont
            subtitleLabel.textAlignment = .center
            subtitleLabel.text = viewModel.subtitleLabelText

            tokenCountLabel.textAlignment = .center
            tokenCountLabel.textColor = viewModel.tokenSaleDetailsLabelColor
            tokenCountLabel.font = viewModel.tokenSaleDetailsLabelFont
            tokenCountLabel.text = viewModel.tokenCountLabelText

            descriptionLabel.textAlignment = .center
            descriptionLabel.numberOfLines = 0
            descriptionLabel.textColor = viewModel.tokenSaleDetailsLabelColor
            descriptionLabel.font = viewModel.tokenSaleDetailsLabelFont
            descriptionLabel.text = viewModel.descriptionLabelText

            detailsBackground.backgroundColor = viewModel.detailsBackgroundBackgroundColor

            actionButton.setTitleColor(viewModel.actionButtonTitleColor, for: .normal)
            actionButton.setBackgroundColor(viewModel.actionButtonBackgroundColor, forState: .normal)
            actionButton.titleLabel?.font = viewModel.actionButtonTitleFont
            actionButton.setTitle(viewModel.actionButtonTitle, for: .normal)
            actionButton.cornerRadius = Metrics.CornerRadius.button

            cancelButton.setTitleColor(viewModel.cancelButtonTitleColor, for: .normal)
            cancelButton.setBackgroundColor(viewModel.cancelButtonBackgroundColor, forState: .normal)
            cancelButton.titleLabel?.font = viewModel.cancelButtonTitleFont
            cancelButton.setTitle(viewModel.cancelButtonTitle, for: .normal)
            cancelButton.layer.masksToBounds = true
        }
    }

    @objc func share() {
        delegate?.didPressShare(in: self, sender: actionButton)
    }

    @objc func cancel() {
        if let delegate = delegate {
            delegate.didPressCancel(in: self)
        } else {
            dismiss(animated: true)
        }
    }
}
