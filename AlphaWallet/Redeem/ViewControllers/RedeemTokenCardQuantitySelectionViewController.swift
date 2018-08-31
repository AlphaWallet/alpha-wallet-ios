//
//  QuantitySelectionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/5/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

protocol RedeemTokenCardQuantitySelectionViewControllerDelegate: class, CanOpenURL {
    func didSelectQuantity(token: TokenObject, ticketHolder: TokenHolder, in viewController: RedeemTokenCardQuantitySelectionViewController)
    func didPressViewInfo(in viewController: RedeemTokenCardQuantitySelectionViewController)
}

class RedeemTokenCardQuantitySelectionViewController: UIViewController, TokenVerifiableStatusViewController {

    let config: Config
    var contract: String {
        return token.contract
    }
    private let token: TokenObject
    let roundedBackground = RoundedBackground()
    let header = TokensCardViewControllerTitleHeader()
	let subtitleLabel = UILabel()
    let quantityStepper = NumberStepper()
    let ticketView: TokenRowView & UIView
    let nextButton = UIButton(type: .system)
    var viewModel: RedeemTokenCardQuantitySelectionViewModel
    weak var delegate: RedeemTokenCardQuantitySelectionViewControllerDelegate?

    init(config: Config, token: TokenObject, viewModel: RedeemTokenCardQuantitySelectionViewModel) {
        self.config = config
        self.token = token
        self.viewModel = viewModel

        let tokenType = CryptoKittyHandling(address: token.address)
        switch tokenType {
        case .cryptoKitty:
            ticketView = TokenListFormatRowView()
        case .otherNonFungibleToken:
            ticketView = TokenCardRowView()
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle(R.string.localizable.aWalletTicketTokenRedeemButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ticketView)

        quantityStepper.translatesAutoresizingMaskIntoConstraints = false
        quantityStepper.minimumValue = 1
        quantityStepper.value = 1
        view.addSubview(quantityStepper)

        let stackView = [
            header,
            subtitleLabel,
            .spacer(height: 4),
            quantityStepper,
            .spacer(height: 50),
            ticketView,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let buttonsStackView = [nextButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

			quantityStepper.heightAnchor.constraint(equalToConstant: 50),

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func nextButtonTapped() {
        if quantityStepper.value == 0 {
            let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName()
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTicketTokenRedeemSelectTicketQuantityAtLeastOneTitle(tokenTypeName),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectQuantity(token: viewModel.token, ticketHolder: getTicketHolderFromQuantity(), in: self)
        }
    }

    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, in: self)
    }

    func configure(viewModel newViewModel: RedeemTokenCardQuantitySelectionViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }

        updateNavigationRightBarButtons(isVerified: isContractVerified)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        subtitleLabel.text = viewModel.subtitleText

        ticketView.configure(tokenHolder: viewModel.ticketHolder)

        quantityStepper.borderWidth = 1
        quantityStepper.clipsToBounds = true
        quantityStepper.borderColor = viewModel.stepperBorderColor
        quantityStepper.maximumValue = viewModel.maxValue

        ticketView.stateLabel.isHidden = true

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    private func getTicketHolderFromQuantity() -> TokenHolder {
        let quantity = quantityStepper.value
        let ticketHolder = viewModel.ticketHolder
        let tickets = Array(ticketHolder.tickets[..<quantity])
        return TokenHolder(
            tickets: tickets,
            status: ticketHolder.status,
            contractAddress: ticketHolder.contractAddress
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        quantityStepper.layer.cornerRadius = quantityStepper.frame.size.height / 2
    }

}
