// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol ChooseTicketTransferModeViewControllerDelegate: class {
    func didChooseTransferViaMagicLink(token: TokenObject, ticketHolder: TicketHolder, in viewController: ChooseTicketTransferModeViewController)
    func didChooseTransferNow(token: TokenObject, ticketHolder: TicketHolder, in viewController: ChooseTicketTransferModeViewController)
    func didPressViewInfo(in viewController: ChooseTicketTransferModeViewController)
}

class ChooseTicketTransferModeViewController: UIViewController {
    let horizontalAdjustmentForLongMagicLinkButtonTitle = CGFloat(20)

    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
    let ticketView = TicketRowView()
    let generateMagicLinkButton = UIButton(type: .system)
    let transferNowButton = UIButton(type: .system)
    var viewModel: ChooseTicketTransferModeViewControllerViewModel!
    var ticketHolder: TicketHolder
    var paymentFlow: PaymentFlow
    weak var delegate: ChooseTicketTransferModeViewControllerDelegate?

    init(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        self.ticketHolder = ticketHolder
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        generateMagicLinkButton.setTitle(R.string.localizable.aWalletTicketTokenTransferModeMagicLinkButtonTitle(), for: .normal)
        generateMagicLinkButton.addTarget(self, action: #selector(generateMagicLinkTapped), for: .touchUpInside)

        transferNowButton.setTitle(R.string.localizable.aWalletTicketTokenTransferModeNowButtonTitle(), for: .normal)
        transferNowButton.addTarget(self, action: #selector(transferNowTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ticketView)

        let stackView = [
            header,
            ticketView,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let buttonsStackView = [generateMagicLinkButton, transferNowButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        let separator0 = UIView()
        separator0.translatesAutoresizingMaskIntoConstraints = false
        separator0.backgroundColor = Colors.appLightButtonSeparator
        footerBar.addSubview(separator0)

        let separatorThickness = CGFloat(1)
        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            separator0.leadingAnchor.constraint(equalTo: generateMagicLinkButton.trailingAnchor, constant: -separatorThickness / 2 + horizontalAdjustmentForLongMagicLinkButtonTitle),
            separator0.trailingAnchor.constraint(equalTo: transferNowButton.leadingAnchor, constant: separatorThickness / 2 + horizontalAdjustmentForLongMagicLinkButtonTitle),
            separator0.topAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: 8),
            separator0.bottomAnchor.constraint(equalTo: buttonsStackView.bottomAnchor, constant: -8),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func generateMagicLinkTapped() {
        delegate?.didChooseTransferViaMagicLink(token: viewModel.token, ticketHolder: ticketHolder, in: self)
    }

    @objc func transferNowTapped() {
        delegate?.didChooseTransferNow(token: viewModel.token, ticketHolder: ticketHolder, in: self)
    }

    @objc func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func configure(viewModel: ChooseTicketTransferModeViewControllerViewModel) {
        self.viewModel = viewModel

        if viewModel.token.contract != Constants.ticketContractAddress {
            navigationItem.rightBarButtonItem = nil
        }

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        ticketView.configure(viewModel: .init(ticketHolder: ticketHolder))

        ticketView.stateLabel.isHidden = true

        generateMagicLinkButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		generateMagicLinkButton.backgroundColor = viewModel.buttonBackgroundColor
        generateMagicLinkButton.titleLabel?.font = viewModel.buttonFont
        //Hardcode position because text is very long compared to the transferNowButton
        generateMagicLinkButton.titleEdgeInsets = .init(top: 0, left: horizontalAdjustmentForLongMagicLinkButtonTitle, bottom: 0, right: 0)

        transferNowButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        transferNowButton.backgroundColor = viewModel.buttonBackgroundColor
        transferNowButton.titleLabel?.font = viewModel.buttonFont
    }
}
