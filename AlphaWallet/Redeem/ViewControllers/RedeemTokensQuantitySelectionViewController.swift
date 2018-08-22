//
//  QuantitySelectionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/5/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

protocol RedeemTokensQuantitySelectionViewControllerDelegate: class {
    func didSelectQuantity(token: TokenObject, TokenHolder: TokenHolder, in viewController: RedeemTokensQuantitySelectionViewController)
    func didPressViewInfo(in viewController: RedeemTokensQuantitySelectionViewController)
    func didPressViewContractWebPage(in viewController: RedeemTokensQuantitySelectionViewController)
}

class RedeemTokensQuantitySelectionViewController: UIViewController, TokenVerifiableStatusViewController {

    let config: Config
    var contract: String {
        return token.contract
    }
    private let token: TokenObject
    let roundedBackground = RoundedBackground()
    let header = TokensViewControllerTitleHeader()
	let subtitleLabel = UILabel()
    var quantityStepper = NumberStepper()
    let TokenView: TokenRowView & UIView
    let nextButton = UIButton(type: .system)
    var viewModel: RedeemTokensQuantitySelectionViewModel
    weak var delegate: RedeemTokensQuantitySelectionViewControllerDelegate?

    init(config: Config, token: TokenObject, viewModel: RedeemTokensQuantitySelectionViewModel) {
        self.config = config
        self.token = token
        self.viewModel = viewModel

        let tokenType = CryptoKittyHandling(address: token.address)
        switch tokenType {
        case .cryptoKitty:
            TokenView = TokenListFormatRowView()
        case .otherNonFungibleToken:
            TokenView = TokenRowView()
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle(R.string.localizable.aWalletTokenTokenRedeemButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        TokenView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(TokenView)

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
            TokenView,
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

            TokenView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            TokenView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

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
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTokenTokenRedeemSelectTokenQuantityAtLeastOneTitle(),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectQuantity(token: viewModel.token, TokenHolder: getTokenHolderFromQuantity(), in: self)
        }
    }

    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(in: self)
    }

    func configure(viewModel newViewModel: RedeemTokensQuantitySelectionViewModel? = nil) {
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

        TokenView.configure(tokenHolder: viewModel.TokenHolder)

        quantityStepper.borderWidth = 1
        quantityStepper.clipsToBounds = true
        quantityStepper.borderColor = viewModel.stepperBorderColor
        quantityStepper.maximumValue = viewModel.maxValue

        TokenView.stateLabel.isHidden = true

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    private func getTokenHolderFromQuantity() -> TokenHolder {
        let quantity = quantityStepper.value
        let TokenHolder = viewModel.TokenHolder
        let Tokens = Array(TokenHolder.Tokens[..<quantity])
        return TokenHolder(
            Tokens: Tokens,
            status: TokenHolder.status,
            contractAddress: TokenHolder.contractAddress
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        quantityStepper.layer.cornerRadius = quantityStepper.frame.size.height / 2
    }

}
