//
//  NFTAssetViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import Combine
import AlphaWalletFoundation

protocol NonFungibleTokenViewControllerDelegate: AnyObject, CanOpenURL {
    func didPressRedeem(token: Token, tokenHolder: TokenHolder, in viewController: NFTAssetViewController)
    func didPressSell(tokenHolder: TokenHolder, in viewController: NFTAssetViewController)
    func didPressTransfer(token: Token, tokenHolder: TokenHolder, paymentFlow: PaymentFlow, in viewController: NFTAssetViewController)
    func didPressViewRedemptionInfo(in viewController: NFTAssetViewController)
    func didTapURL(url: URL, in viewController: NFTAssetViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: NFTAssetViewController)
}

class NFTAssetViewController: UIViewController, TokenVerifiableStatusViewController {
    private var previewView: NFTPreviewViewRepresentable
    private let buttonsBar = HorizontalButtonsBar(configuration: .combined(buttons: 3))
    private lazy var containerView: ScrollableStackView = ScrollableStackView()
    private lazy var attributesStackView = GridStackView(viewModel: .init(edgeInsets: .init(top: 0, left: 16, bottom: 15, right: 16)))
    private var cancelable = Set<AnyCancellable>()
    private let appear = PassthroughSubject<Void, Never>()
    private let action = PassthroughSubject<TokenInstanceAction, Never>()
    private let selection = PassthroughSubject<IndexPath, Never>()
    private let viewModel: NFTAssetViewModel

    var server: RPCServer {
        return viewModel.token.server
    }
    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    var assetDefinitionStore: AssetDefinitionStore {
        return viewModel.assetDefinitionStore
    }
    weak var delegate: NonFungibleTokenViewControllerDelegate?

    init(viewModel: NFTAssetViewModel, tokenCardViewFactory: TokenCardViewFactory) {
        self.viewModel = viewModel
        self.previewView = tokenCardViewFactory.createPreview(
            of: viewModel.previewViewType,
            session: viewModel.session,
            edgeInsets: viewModel.previewEdgeInsets,
            playButtonPositioning: .bottomRight)
        
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
        title = viewModel.title
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
        appear.send(())
    }

    override func viewWillDisappear(_ animated: Bool) {
        title = ""
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
        previewView.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        containerView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: NFTAssetViewModel) {
        title = viewModel.title

        let input = NFTAssetViewModelInput(
            appear: appear.eraseToAnyPublisher(),
            action: action.eraseToAnyPublisher(),
            selection: selection.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.state
            .sink { [weak self, weak previewView] state in
                self?.title = state.title
                previewView?.configure(params: state.previewViewParams)
                previewView?.contentBackgroundColor = state.previewViewContentBackgroundColor
                self?.generateSubviews(for: state.viewTypes)
                self?.configureActionButtons(state.actionButtons)
            }.store(in: &cancelable)

        output.nftAssetAction
            .sink { [weak self] in self?.handle(action: $0) }
            .store(in: &cancelable)

        output.attributeSelectionAction
            .sink { [weak self] in self?.handle(attributeSelectionAction: $0) }
            .store(in: &cancelable)
    }

    private func handle(attributeSelectionAction action: NFTAssetViewModel.AttributeSelectionAction) {
        switch action {
        case .openContractWebPage(let url):
            delegate?.didPressViewContractWebPage(url, in: self)
        case .showCopiedToClipboard(let title):
            self.view.showCopiedToClipboard(title: title)
        }
    }

    private func handle(action: NFTAssetViewModel.NftAssetAction) {
        switch action {
        case .redeem(let token, let tokenHolder):
            delegate?.didPressRedeem(token: token, tokenHolder: tokenHolder, in: self)
        case .sell(let tokenHolder):
            delegate?.didPressSell(tokenHolder: tokenHolder, in: self)
        case .transfer(let token, let tokenHolder, let transactionType):
            delegate?.didPressTransfer(token: token, tokenHolder: tokenHolder, paymentFlow: .send(type: .transaction(transactionType)), in: self)
        case .display(let warning):
            UIAlertController.alert(message: warning, alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.default], viewController: self)
        case .tokenScript(let action, let tokenHolder):
            delegate?.didTap(action: action, tokenHolder: tokenHolder, viewController: self)
        }
    }

    private func configureActionButtons(_ buttons: [FungibleTokenDetailsViewModel.ActionButton]) {
        buttonsBar.cancellable.cancellAll()

        buttonsBar.configure(.combined(buttons: buttons.count))
        buttonsBar.viewController = self

        for (button, view) in zip(buttons, buttonsBar.buttons) {
            view.setTitle(button.name, for: .normal)
            view.publisher(forEvent: .touchUpInside)
                .map { _ in button.actionType }
                .multicast(subject: action)
                .connect()
                .store(in: &buttonsBar.cancellable)

            switch button.state {
            case .isEnabled(let isEnabled):
                view.isEnabled = isEnabled
            case .isDisplayed(let isDisplayed):
                view.displayButton = isDisplayed
            case .noOption:
                continue
            }
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
        selection.send(view.indexPath)
    }
}
