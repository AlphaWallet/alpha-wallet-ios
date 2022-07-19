// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol GenerateSellMagicLinkViewControllerDelegate: AnyObject {
    func didPressShare(in viewController: GenerateSellMagicLinkViewController, sender: UIView)
    func didPressCancel(in viewController: GenerateSellMagicLinkViewController)
}

class GenerateSellMagicLinkViewController: UIViewController {
    private let background = UIView()
	private let header = TokensCardViewControllerTitleHeader()
    private let detailsBackground = UIView()
    private let subtitleLabel = UILabel()
    private let tokenCountLabel = UILabel()
    private let perTokenPriceLabel = UILabel()
    private let totalEthLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let actionButton = UIButton()
    private let cancelButton = UIButton()
    private var viewModel: GenerateSellMagicLinkViewControllerViewModel?

    weak var delegate: GenerateSellMagicLinkViewControllerDelegate?
    let paymentFlow: PaymentFlow
    let tokenHolder: TokenHolder
    let ethCost: Ether
    let linkExpiryDate: Date

    init(paymentFlow: PaymentFlow, tokenHolder: TokenHolder, ethCost: Ether, linkExpiryDate: Date) {
        self.paymentFlow = paymentFlow
        self.tokenHolder = tokenHolder
        self.ethCost = ethCost
        self.linkExpiryDate = linkExpiryDate
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .clear

        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(visualEffectView, at: 0)

        view.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        tokenCountLabel.translatesAutoresizingMaskIntoConstraints = false
        perTokenPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        totalEthLabel.translatesAutoresizingMaskIntoConstraints = false
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
            perTokenPriceLabel,
            totalEthLabel,
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

            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            detailsBackground.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            detailsBackground.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            detailsBackground.topAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -12),
            detailsBackground.bottomAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),

            actionButton.heightAnchor.constraint(equalToConstant: 47),
            cancelButton.heightAnchor.constraint(equalTo: actionButton.heightAnchor),

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -30),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -16),

            background.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 42),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
            background.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: GenerateSellMagicLinkViewControllerViewModel) {
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

            perTokenPriceLabel.textAlignment = .center
            perTokenPriceLabel.textColor = viewModel.tokenSaleDetailsLabelColor
            perTokenPriceLabel.font = viewModel.tokenSaleDetailsLabelFont
            perTokenPriceLabel.text = viewModel.perTokenPriceLabelText
            perTokenPriceLabel.adjustsFontSizeToFitWidth = true

            totalEthLabel.textAlignment = .center
            totalEthLabel.textColor = viewModel.tokenSaleDetailsLabelColor
            totalEthLabel.font = viewModel.tokenSaleDetailsLabelFont
            totalEthLabel.text = viewModel.totalEthLabelText
            totalEthLabel.adjustsFontSizeToFitWidth = true

            descriptionLabel.textAlignment = .center
            descriptionLabel.numberOfLines = 0
            descriptionLabel.textColor = viewModel.tokenSaleDetailsLabelColor
            descriptionLabel.font = viewModel.tokenSaleDetailsLabelFont
            descriptionLabel.text = viewModel.descriptionLabelText

            detailsBackground.backgroundColor = viewModel.detailsBackgroundBackgroundColor

            actionButton.setTitleColor(viewModel.actionButtonTitleColor, for: .normal)
            actionButton.setBackgroundColor(viewModel.actionButtonBackgroundColor, forState: .normal, darkModeEnabled: false)
            actionButton.titleLabel?.font = viewModel.actionButtonTitleFont
            actionButton.setTitle(viewModel.actionButtonTitle, for: .normal)
            actionButton.cornerRadius = Metrics.CornerRadius.button

            cancelButton.setTitleColor(viewModel.cancelButtonTitleColor, for: .normal)
            cancelButton.setBackgroundColor(viewModel.cancelButtonBackgroundColor, forState: .normal, darkModeEnabled: false)
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
