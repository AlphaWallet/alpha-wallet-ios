// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol GenerateTransferMagicLinkViewControllerDelegate: class {
    func didPressShare(in viewController: GenerateTransferMagicLinkViewController, sender: UIView)
    func didPressCancel(in viewController: GenerateTransferMagicLinkViewController)
}

class GenerateTransferMagicLinkViewController: UIViewController {
    weak var delegate: GenerateTransferMagicLinkViewControllerDelegate?
    let background = UIView()
	let header = TicketsViewControllerTitleHeader()
    let detailsBackground = UIView()
    let subtitleLabel = UILabel()
    let ticketCountLabel = UILabel()
    let descriptionLabel = UILabel()
    let actionButton = UIButton()
    let cancelButton = UIButton()
    var paymentFlow: PaymentFlow
    var ticketHolder: TicketHolder
    var linkExpiryDate: Date
    var viewModel: GenerateTransferMagicLinkViewControllerViewModel?

    init(paymentFlow: PaymentFlow, ticketHolder: TicketHolder, linkExpiryDate: Date) {
        self.paymentFlow = paymentFlow
        self.ticketHolder = ticketHolder
        self.linkExpiryDate = linkExpiryDate
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .clear

        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(visualEffectView, at: 0)

        view.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        ticketCountLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        detailsBackground.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(detailsBackground)

        actionButton.addTarget(self, action: #selector(share), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let stackView = [
            header,
            .spacer(height: 20),
            subtitleLabel,
            ticketCountLabel,
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

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -40),
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

    func configure(viewModel: GenerateTransferMagicLinkViewControllerViewModel) {
        self.viewModel = viewModel
        if let viewModel = self.viewModel {
            background.backgroundColor = viewModel.contentsBackgroundColor
            background.layer.cornerRadius = 20

            header.configure(title: viewModel.headerTitle)

            subtitleLabel.numberOfLines = 0
            subtitleLabel.textColor = viewModel.subtitleColor
            subtitleLabel.font = viewModel.subtitleFont
            subtitleLabel.textAlignment = .center
            subtitleLabel.text = viewModel.subtitleLabelText

            ticketCountLabel.textAlignment = .center
            ticketCountLabel.textColor = viewModel.ticketSaleDetailsLabelColor
            ticketCountLabel.font = viewModel.ticketSaleDetailsLabelFont
            ticketCountLabel.text = viewModel.ticketCountLabelText

            descriptionLabel.textAlignment = .center
            descriptionLabel.numberOfLines = 0
            descriptionLabel.textColor = viewModel.ticketSaleDetailsLabelColor
            descriptionLabel.font = viewModel.ticketSaleDetailsLabelFont
            descriptionLabel.text = viewModel.descriptionLabelText

            detailsBackground.backgroundColor = viewModel.detailsBackgroundBackgroundColor

            actionButton.setTitleColor(viewModel.actionButtonTitleColor, for: .normal)
            actionButton.setBackgroundColor(viewModel.actionButtonBackgroundColor, forState: .normal)
            actionButton.titleLabel?.font = viewModel.actionButtonTitleFont
            actionButton.setTitle(viewModel.actionButtonTitle, for: .normal)
            actionButton.layer.masksToBounds = true

            cancelButton.setTitleColor(viewModel.cancelButtonTitleColor, for: .normal)
            cancelButton.setBackgroundColor(viewModel.cancelButtonBackgroundColor, forState: .normal)
            cancelButton.titleLabel?.font = viewModel.cancelButtonTitleFont
            cancelButton.setTitle(viewModel.cancelButtonTitle, for: .normal)
            cancelButton.layer.masksToBounds = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        actionButton.layer.cornerRadius = actionButton.frame.size.height / 2
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
