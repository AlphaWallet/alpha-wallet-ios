//
//  NFTAssetViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import Combine
import AlphaWalletFoundation

protocol NonFungibleTokenViewControllerDelegate: class, CanOpenURL {
    func didPressRedeem(token: Token, tokenHolder: TokenHolder, in viewController: NFTAssetViewController)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: NFTAssetViewController)
    func didPressTransfer(token: Token, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: NFTAssetViewController)
    func didPressViewRedemptionInfo(in viewController: NFTAssetViewController)
    func didTapURL(url: URL, in viewController: NFTAssetViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: NFTAssetViewController)
}

class NFTAssetViewController: UIViewController, TokenVerifiableStatusViewController {
    private let previewView: NFTPreviewView
    private let buttonsBar = HorizontalButtonsBar(configuration: .combined(buttons: 3))
    private lazy var containerView: ScrollableStackView = ScrollableStackView()
    private lazy var attributesStackView = GridStackView(viewModel: .init(edgeInsets: .init(top: 0, left: 16, bottom: 15, right: 16)))
    private var cancelable = Set<AnyCancellable>()
    private let appear = PassthroughSubject<Void, Never>()

    let viewModel: NFTAssetViewModel
    var server: RPCServer {
        return viewModel.token.server
    }
    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: NonFungibleTokenViewControllerDelegate?

    init(analytics: AnalyticsLogger, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, keystore: Keystore, viewModel: NFTAssetViewModel) {
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = viewModel
        self.previewView = .init(type: viewModel.previewViewType, keystore: keystore, session: session, assetDefinitionStore: assetDefinitionStore, analytics: analytics, edgeInsets: viewModel.previewEdgeInsets)
        self.previewView.rounding = .custom(20)
        self.previewView.contentMode = .scaleAspectFill
        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        let stackView = [containerView, footerBar].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        let previewHeightConstraint: [NSLayoutConstraint]
        switch viewModel.previewViewType {
        case .imageView:
            previewHeightConstraint = [previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor)]
        case .tokenCardView:
            previewHeightConstraint = []
        }

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view),
            previewHeightConstraint
        ])

        previewView.configure(params: viewModel.previewViewParams)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    } 

    //NOTE: Blank out the title before pushing the send screen because longer (not even very long ones) titles will overlay the Send screen's back button
    override func viewWillAppear(_ animated: Bool) {
        title = viewModel.navigationTitle
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
        appear.send(())
    }

    override func viewWillDisappear(_ animated: Bool) {
        title = ""
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: NFTAssetViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        containerView.backgroundColor = viewModel.backgroundColor
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)
        title = viewModel.navigationTitle

        let input = NFTAssetViewModelInput(appear: appear.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.state.sink { [weak self, weak previewView] state in
            self?.title = state.navigationTitle
            previewView?.configure(params: state.previewViewParams)
            previewView?.contentBackgroundColor = state.previewViewContentBackgroundColor
            self?.generateSubviews(for: state.viewTypes)
            self?.configureActionButtons(with: state.actions)
        }.store(in: &cancelable)
    }

    private func configureActionButtons(with actions: [TokenInstanceAction]) {
        buttonsBar.configure(.combined(buttons: actions.count))

        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)

            switch viewModel.buttonState(for: action) {
            case .isEnabled(let isEnabled):
                button.isEnabled = isEnabled
            case .isDisplayed(let isDisplayed):
                button.displayButton = isDisplayed
            case .noOption:
                continue
            }
        }
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .nftRedeem:
                delegate?.didPressRedeem(token: viewModel.token, tokenHolder: viewModel.tokenHolder, in: self)
            case .nftSell:
                delegate?.didPressSell(tokenHolder: viewModel.tokenHolder, for: .send(type: .transaction(viewModel.sellTransactionType)), in: self)
            case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
                //TODO when we support TokenScript views for ERC20s, we need to perform the action here
                break
            case .nonFungibleTransfer:
                delegate?.didPressTransfer(token: viewModel.token, tokenHolder: viewModel.tokenHolder, forPaymentFlow: .send(type: .transaction(viewModel.transferTransactionType)), in: self)
            case .tokenScript:
                if let message = viewModel.tokenScriptWarningMessage(for: action) {
                    guard case .warning(let denialMessage) = message else { return }
                    UIAlertController.alert(message: denialMessage, alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.default], viewController: self)
                } else {
                    delegate?.didTap(action: action, tokenHolder: viewModel.tokenHolder, viewController: self)
                }
            }
            break
        }
    }

    private func generateSubviews(for viewTypes: [NFTAssetViewModel.ViewType]) {
        containerView.stackView.removeAllArrangedSubviews()

        containerView.stackView.addArrangedSubview(previewView)

        for (index, each) in viewTypes.enumerated() {
            switch each {
            case .header(let viewModel):
                let header = TokenInfoHeaderView(edgeInsets: .init(top: 16, left: 16, bottom: 20, right: 0))
                header.configure(viewModel: viewModel)

                containerView.stackView.addArrangedSubview(header)
            case .field(let viewModel):
                let view = TokenAttributeView(indexPath: IndexPath(row: index, section: 0))
                view.configure(viewModel: viewModel)
                view.delegate = self

                containerView.stackView.addArrangedSubview(view)
            case .attributeCollection(let viewModel):
                var views: [UIView] = []
                for (row, attribute) in viewModel.traits.enumerated() {
                    let view = NonFungibleTraitView(edgeInsets: .init(top: 10, left: 10, bottom: 10, right: 10), indexPath: IndexPath(row: row, section: index))
                    view.configure(viewModel: attribute)

                    views.append(view)
                }
                attributesStackView.set(subviews: views)

                containerView.stackView.addArrangedSubview(attributesStackView)
            }
        }
    }
}

extension NFTAssetViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewRedemptionInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: viewModel.token.contractAddress, server: viewModel.token.server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension NFTAssetViewController: TokenAttributeViewDelegate {
    func didSelect(in view: TokenAttributeView) {
        switch viewModel.viewTypes[view.indexPath.row] {
        case .field(let vm) where viewModel.tokenIdViewModel == vm:
            UIPasteboard.general.string = vm.value

            self.view.showCopiedToClipboard(title: R.string.localizable.copiedToClipboard())
        case .field(let vm) where viewModel.creatorViewModel == vm:
            guard let url = viewModel.creatorOnOpenSeaUrl else { return }

            delegate?.didPressViewContractWebPage(url, in: self)
        case .field(let vm) where viewModel.contractViewModel == vm:
            guard let url = viewModel.contractOnExplorerUrl else { return }

            delegate?.didPressViewContractWebPage(url, in: self)
        case .header, .field, .attributeCollection:
            break
        }
    }
}
