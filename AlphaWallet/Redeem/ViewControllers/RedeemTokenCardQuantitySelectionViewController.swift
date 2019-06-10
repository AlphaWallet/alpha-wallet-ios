//
//  QuantitySelectionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/5/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

protocol RedeemTokenCardQuantitySelectionViewControllerDelegate: class, CanOpenURL {
    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: RedeemTokenCardQuantitySelectionViewController)
    func didPressViewInfo(in viewController: RedeemTokenCardQuantitySelectionViewController)
}

class RedeemTokenCardQuantitySelectionViewController: UIViewController, TokenVerifiableStatusViewController {
    private let token: TokenObject
    private let roundedBackground = RoundedBackground()
    private let header = TokensCardViewControllerTitleHeader()
	private let subtitleLabel = UILabel()
    private let quantityStepper = NumberStepper()
    private let tokenRowView: TokenRowView & UIView
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
    private var viewModel: RedeemTokenCardQuantitySelectionViewModel

    var contract: String {
        return token.contract
    }
    var server: RPCServer {
        return token.server
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: RedeemTokenCardQuantitySelectionViewControllerDelegate?

    init(token: TokenObject, viewModel: RedeemTokenCardQuantitySelectionViewModel, assetDefinitionStore: AssetDefinitionStore) {
        self.token = token
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaNonFungibleTokenHandling(token: token)
        switch tokenType {
        case .supportedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notSupportedByOpenSea:
            tokenRowView = TokenCardRowView(server: token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tokenRowView)

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
            tokenRowView,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

			quantityStepper.heightAnchor.constraint(equalToConstant: 50),

            tokenRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func nextButtonTapped() {
        if quantityStepper.value == 0 {
            let tokenTypeName = XMLHandler(contract: token.address.eip55String, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTokenRedeemSelectTokenQuantityAtLeastOneTitle(tokenTypeName),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectQuantity(token: viewModel.token, tokenHolder: getTokenHolderFromQuantity(), in: self)
        }
    }

    func configure(viewModel newViewModel: RedeemTokenCardQuantitySelectionViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }

        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        subtitleLabel.text = viewModel.subtitleText

        tokenRowView.configure(tokenHolder: viewModel.tokenHolder)

        quantityStepper.borderWidth = 1
        quantityStepper.clipsToBounds = true
        quantityStepper.borderColor = viewModel.stepperBorderColor
        quantityStepper.maximumValue = viewModel.maxValue

        tokenRowView.stateLabel.isHidden = true

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.aWalletTokenRedeemButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }

    private func getTokenHolderFromQuantity() -> TokenHolder {
        let quantity = quantityStepper.value
        let tokenHolder = viewModel.tokenHolder
        let tokens = Array(tokenHolder.tokens[..<quantity])
        return TokenHolder(
            tokens: tokens,
            contractAddress: tokenHolder.contractAddress,
            hasAssetDefinition: tokenHolder.hasAssetDefinition
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        quantityStepper.layer.cornerRadius = quantityStepper.frame.size.height / 2
    }
}

extension RedeemTokenCardQuantitySelectionViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}
