// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TransferTokenCardQuantitySelectionViewControllerDelegate: class, CanOpenURL {
    func didSelectQuantity(token: TokenObject, tokenHolder: TokenHolder, in viewController: TransferTokensCardQuantitySelectionViewController)
    func didPressViewInfo(in viewController: TransferTokensCardQuantitySelectionViewController)
}

class TransferTokensCardQuantitySelectionViewController: UIViewController, TokenVerifiableStatusViewController {
    private let roundedBackground = RoundedBackground()
    private let header = TokensCardViewControllerTitleHeader()
	private let subtitleLabel = UILabel()
    private let quantityStepper = NumberStepper()
    private let tokenRowView: TokenRowView & UIView
    private let nextButton = UIButton(type: .system)
    private var viewModel: TransferTokensCardQuantitySelectionViewModel
    private let token: TokenObject

    let config: Config
    var contract: String {
        return token.contract
    }
    let paymentFlow: PaymentFlow
    weak var delegate: TransferTokenCardQuantitySelectionViewControllerDelegate?

    init(
            config: Config = Config(),
            paymentFlow: PaymentFlow,
            token: TokenObject,
            viewModel: TransferTokensCardQuantitySelectionViewModel
    ) {
        self.config = config
        self.paymentFlow = paymentFlow
        self.token = token
        self.viewModel = viewModel

        let tokenType = OpenSeaNonFungibleTokenHandling(token: token)
        switch tokenType {
        case .supportedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView()
        case .notSupportedByOpenSea:
            tokenRowView = TokenCardRowView()
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tokenRowView)

        quantityStepper.translatesAutoresizingMaskIntoConstraints = false
        quantityStepper.minimumValue = 1
        quantityStepper.value = 1
        view.addSubview(quantityStepper)

        let stackView = [
            header,
            tokenRowView,
            .spacer(height: 20),
            subtitleLabel,
            .spacer(height: 4),
            quantityStepper,
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

            tokenRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

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
                                    message: R.string.localizable.aWalletTokenTransferSelectTokenQuantityAtLeastOneTitle(tokenTypeName),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectQuantity(token: viewModel.token, tokenHolder: getTokenHolderFromQuantity(), in: self)
        }
    }

    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, in: self)
    }

    func configure(viewModel newViewModel: TransferTokensCardQuantitySelectionViewModel? = nil) {
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

        tokenRowView.configure(tokenHolder: viewModel.tokenHolder)

        quantityStepper.borderWidth = 1
        quantityStepper.clipsToBounds = true
        quantityStepper.borderColor = viewModel.stepperBorderColor
        quantityStepper.maximumValue = viewModel.maxValue

        tokenRowView.stateLabel.isHidden = true

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
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
