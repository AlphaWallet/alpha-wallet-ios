//
//  TransferTokenBatchCardsViaWalletAddressViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol TransferTokenBatchCardsViaWalletAddressViewControllerDelegate: class, CanOpenURL {
    func didEnterWalletAddress(tokenHolders: [TokenHolder], to recipient: AlphaWallet.Address, in viewController: TransferTokenBatchCardsViaWalletAddressViewController)
    func openQRCode(in controller: TransferTokenBatchCardsViaWalletAddressViewController)
    func didSelectTokenHolder(tokenHolder: TokenHolder, in viewController: TransferTokenBatchCardsViaWalletAddressViewController)
}

//TODO: support ERC1155 fungibles (where decimals is provided and > 0)
class TransferTokenBatchCardsViaWalletAddressViewController: UIViewController, TokenVerifiableStatusViewController {
    private let token: TokenObject
    private lazy var targetAddressTextField: AddressTextField = {
        let textField = AddressTextField(domainResolutionService: domainResolutionService)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.returnKeyType = .done

        return textField
    }()

    private lazy var recipientHeaderView: SendViewSectionHeader = {
        let view = SendViewSectionHeader()
        view.configure(viewModel: .init(text: R.string.localizable.sendRecipient().uppercased(), showTopSeparatorLine: false))

        return view
    }()

    private lazy var amountHeaderView: SendViewSectionHeader = {
        let view = SendViewSectionHeader()
        view.configure(viewModel: .init(text: R.string.localizable.sendAmount().uppercased()))

        return view
    }()

    private lazy var selectedTokenCardsHeaderView: SendViewSectionHeader = {
        let view = SendViewSectionHeader()
        view.configure(viewModel: .init(text: R.string.localizable.semifungiblesSelectedTokens()))
        return view
    }()

    private lazy var selectTokenCardAmountView: SelectTokenCardAmountView = {
        let view = SelectTokenCardAmountView(viewModel: .init(availableAmount: 0, selectedAmount: 0))
        view.delegate = self

        return view
    }()

    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var viewModel: TransferTokenBatchCardsViaWalletAddressViewControllerViewModel
    private let tokenCardViewFactory: TokenCardViewFactory
    private let domainResolutionService: DomainResolutionServiceType

    var contract: AlphaWallet.Address {
        return token.contractAddress
    }
    var server: RPCServer {
        return token.server
    }
    var assetDefinitionStore: AssetDefinitionStore {
        tokenCardViewFactory.assetDefinitionStore
    }
    weak var delegate: TransferTokenBatchCardsViaWalletAddressViewControllerDelegate?

    lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    init(token: TokenObject, viewModel: TransferTokenBatchCardsViaWalletAddressViewControllerViewModel, tokenCardViewFactory: TokenCardViewFactory, domainResolutionService: DomainResolutionServiceType) {
        self.token = token
        self.viewModel = viewModel
        self.tokenCardViewFactory = tokenCardViewFactory
        self.domainResolutionService = domainResolutionService

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])

        generateSubviews(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func generateSubviews(viewModel: TransferTokenBatchCardsViaWalletAddressViewControllerViewModel) {
        containerView.stackView.removeAllArrangedSubviews()

        let subViews: [UIView] = [
            recipientHeaderView,
            targetAddressTextField.defaultLayout(edgeInsets: .init(top: 16, left: 16, bottom: 16, right: 16)),
            amountHeaderView,
            selectTokenCardAmountView,
            selectedTokenCardsHeaderView
        ] + generateViewsForSelectedTokenHolders(viewModel: viewModel)

        containerView.stackView.addArrangedSubviews(subViews)
    }

    private func generateViewsForSelectedTokenHolders(viewModel: TransferTokenBatchCardsViaWalletAddressViewControllerViewModel) -> [UIView] {
        var subviews: [UIView] = []
        for (index, each) in viewModel.tokenHolders.enumerated() {
            subviews += [
                generateViewFor(tokenHolder: each, index: index),
                UIView.spacer(backgroundColor: R.color.mike()!)
            ]
        }

        return subviews
    }

    private func generateViewFor(tokenHolder: TokenHolder, index: Int) -> UIView {
        let subview = tokenCardViewFactory.create(for: tokenHolder, layout: .list, listEdgeInsets: .init(top: 16, left: 20, bottom: 16, right: 16))

        configureToAllowSelection(subview, tokenHolder: tokenHolder, index: index)
        configure(subview: subview, tokenId: tokenHolder.tokenId, tokenHolder: tokenHolder)

        return subview
    }

    private func configureToAllowSelection(_ subview: UIView, tokenHolder: TokenHolder, index: Int) {
        subview.isUserInteractionEnabled = true
        UITapGestureRecognizer(addToView: subview) { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.didSelectTokenHolder(tokenHolder: tokenHolder, in: strongSelf)
        }
    }

    private func configure(subview: UIView & TokenCardRowViewConfigurable, tokenId: TokenId, tokenHolder: TokenHolder) {
        if let typeSubView = subview as? NonFungibleRowView {
            var viewModel = NonFungibleRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId)
            viewModel.titleColor = Colors.appText
            viewModel.titleFont = Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 13 : 17)

            typeSubView.configure(viewModel: viewModel)
        } else {
            subview.configure(tokenHolder: tokenHolder, tokenId: tokenId)
        }
    }

    @objc func nextButtonTapped() {
        targetAddressTextField.errorState = .none

        if let address = AlphaWallet.Address(string: targetAddressTextField.value.trimmed) {
            delegate?.didEnterWalletAddress(tokenHolders: viewModel.tokenHolders, to: address, in: self)
        } else {
            targetAddressTextField.errorState = .error(Errors.invalidAddress.prettyError)
        }
    }

    func configure(viewModel newViewModel: TransferTokenBatchCardsViaWalletAddressViewControllerViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }

        title = viewModel.navigationTitle
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        view.backgroundColor = viewModel.backgroundColor

        targetAddressTextField.label.attributedText = viewModel.targetAddressAttributedString
        targetAddressTextField.configureOnce()

        selectTokenCardAmountView.configure(viewModel: viewModel.selectionViewModel)

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.confirmPaymentConfirmButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        amountHeaderView.isHidden = viewModel.isAmountSelectionHidden
        selectTokenCardAmountView.isHidden = viewModel.isAmountSelectionHidden
    }
}

extension TransferTokenBatchCardsViaWalletAddressViewController: VerifiableStatusViewController {
    func showInfo() {
        //no-op
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension TransferTokenBatchCardsViaWalletAddressViewController: AddressTextFieldDelegate {

    func didScanQRCode(_ result: String) {
        switch QRCodeValueParser.from(string: result) {
        case .address(let address):
            targetAddressTextField.value = address.eip55String
        case .eip681, .none:
            break
        }
    }

    func displayError(error: Error, for textField: AddressTextField) {
        targetAddressTextField.errorState = .error(Errors.invalidAddress.prettyError)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        delegate?.openQRCode(in: self)
    }

    func didPaste(in textField: AddressTextField) {
        textField.errorState = .none
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        view.endEditing(true)
        return true
    }

    func didChange(to string: String, in textField: AddressTextField) {
        //no-op
    }
}

extension TransferTokenBatchCardsViaWalletAddressViewController: SelectTokenCardAmountViewDelegate {
    func valueDidChange(in view: SelectTokenCardAmountView) {
        viewModel.updateSelectedAmount(view.viewModel.counter)
    }
}

