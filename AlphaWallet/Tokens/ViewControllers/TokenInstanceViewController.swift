// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenInstanceViewControllerDelegate: class, CanOpenURL {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokenInstanceViewController)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController)
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController)
    func didPressViewRedemptionInfo(in viewController: TokenInstanceViewController)
    func didTapURL(url: URL, in viewController: TokenInstanceViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokenInstanceViewController)
}

class TokenInstanceViewController: UIViewController, TokenVerifiableStatusViewController {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenObject: TokenObject
    private var viewModel: TokenInstanceViewModel
    private let account: Wallet
    private let header = TokenCardsViewControllerHeader()
    private let roundedBackground = RoundedBackground()
    private lazy var tokenRowView: TokenCardRowViewProtocol & UIView = createTokenRowView()
    private let separators = (bar: UIView(), line: UIView())
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 3))

    var tokenHolder: TokenHolder {
        return viewModel.tokenHolder
    }
    var server: RPCServer {
        return tokenObject.server
    }
    var contract: AlphaWallet.Address {
        return tokenObject.contractAddress
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: TokenInstanceViewControllerDelegate?

    var isReadOnly = false {
        didSet {
            configure()
        }
    }

    var canPeekToken: Bool {
        let tokenType = NonFungibleFromJsonSupportedTokenHandling(token: tokenObject)
        switch tokenType {
        case .supported:
            return true
        case .notSupported:
            return false
        }
    }

    init(analyticsCoordinator: AnalyticsCoordinator, tokenObject: TokenObject, tokenHolder: TokenHolder, account: Wallet, assetDefinitionStore: AssetDefinitionStore) {
        self.analyticsCoordinator = analyticsCoordinator
        self.tokenObject = tokenObject
        self.account = account
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = .init(token: tokenObject, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        super.init(nibName: nil, bundle: nil)

        let stackView = [
            header,
            separators.bar,
            separators.line,
            tokenRowView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        header.delegate = self

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        roundedBackground.addSubview(footerBar)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: TokenCardsViewControllerHeader.height),

            separators.bar.heightAnchor.constraint(equalToConstant: 5),
            separators.line.heightAnchor.constraint(equalToConstant: 2),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            stackView.bottomAnchor.constraint(greaterThanOrEqualTo: footerBar.topAnchor),
            footerBar.anchorsConstraint(to: view),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel newViewModel: TokenInstanceViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        separators.bar.backgroundColor = GroupedTable.Color.background
        separators.line.backgroundColor = GroupedTable.Color.cellSeparator

        header.configure(viewModel: .init(tokenObject: tokenObject, server: tokenObject.server, assetDefinitionStore: assetDefinitionStore))

        buttonsBar.configure(.combined(buttons: viewModel.actions.count))
        buttonsBar.viewController = self

        for (index, button) in buttonsBar.buttons.enumerated() {
            let action = viewModel.actions[index]
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            switch account.type {
            case .real:
                if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: account.address) {
                    if selection.denial == nil {
                        button.displayButton = false
                    }
                }
            case .watch:
                button.isEnabled = false
            }
        }

        tokenRowView.configure(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId, tokenView: .view, areDetailsVisible: tokenHolder.areDetailsVisible, width: 0, assetDefinitionStore: assetDefinitionStore)
    }

    func firstMatchingTokenHolder(fromTokenHolders tokenHolders: [TokenHolder]) -> TokenHolder? {
        return tokenHolders.first { $0.tokens[0].id == tokenHolder.tokens[0].id }
    }

    func redeem() {
        delegate?.didPressRedeem(token: tokenObject, tokenHolder: tokenHolder, in: self)
    }

    func sell() {
        delegate?.didPressSell(tokenHolder: tokenHolder, for: .send(type: .transaction(.erc875Token(tokenObject, tokenHolders: [tokenHolder]))), in: self)
    }

    func transfer() {
        let transactionType = TransactionType(token: tokenObject, tokenHolders: [tokenHolder])
        delegate?.didPressTransfer(token: tokenObject, tokenHolder: tokenHolder, forPaymentFlow: .send(type: .transaction(transactionType)), in: self)
    }

    @objc func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
                //TODO when we support TokenScript views for ERC20s, we need to perform the action here
                break
            case .nftRedeem:
                redeem()
            case .nftSell:
                sell()
            case .nonFungibleTransfer:
                transfer()
            case .tokenScript:
                if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: account.address) {
                    if let denialMessage = selection.denial {
                        UIAlertController.alert(
                                title: nil,
                                message: denialMessage,
                                alertButtonTitles: [R.string.localizable.oK()],
                                alertButtonStyles: [.default],
                                viewController: self,
                                completion: nil
                        )
                    } else {
                        //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                    }
                } else {
                    delegate?.didTap(action: action, tokenHolder: tokenHolder, viewController: self)
                }
            }

            break
        }
    }

    private func createTokenRowView() -> TokenCardRowViewProtocol & UIView {
        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: tokenObject, assetDefinitionStore: assetDefinitionStore, tokenViewType: .view)
        let rowView: TokenCardRowViewProtocol & UIView
        switch tokenType {
        case .backedByOpenSea:
            rowView = {
                let rowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .view, showCheckbox: false)
                rowView.delegate = self

                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tappedOpenSeaTokenCardRowView))
                rowView.addGestureRecognizer(tapGestureRecognizer)

                return rowView
            }()
        case .notBackedByOpenSea:
            rowView = {
                let view = TokenCardRowView(analyticsCoordinator: analyticsCoordinator, server: server, tokenView: .view, showCheckbox: false, assetDefinitionStore: assetDefinitionStore)
                view.isStandalone = true
                view.tokenScriptRendererView.isWebViewInteractionEnabled = true
                return view
            }()
        }
        return rowView
    }

    @objc private func tappedOpenSeaTokenCardRowView() {
        //We don't allow user to toggle (despite it not doing anything) for non-opensea-backed tokens because it will cause TokenScript views to flash as they have to be re-rendered
        switch OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .view) {
        case .backedByOpenSea:
            viewModel.toggleSelection(for: .init(row: 0, section: 0))
            configure()
        case .notBackedByOpenSea:
            break
        }
    }
}

extension TokenInstanceViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewRedemptionInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: tokenObject.contractAddress, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension TokenInstanceViewController: BaseTokenCardTableViewCellDelegate {
    func didTapURL(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension TokenInstanceViewController: TokenCardsViewControllerHeaderDelegate {
    func didPressViewContractWebPage(inHeaderView: TokenCardsViewControllerHeader) {
        showContractWebPage()
    }
}

extension TokenInstanceViewController: OpenSeaNonFungibleTokenCardRowViewDelegate {
    //Implemented as part of implementing BaseOpenSeaNonFungibleTokenCardTableViewCellDelegate
//    func didTapURL(url: URL) {
//        delegate?.didPressOpenWebPage(url, in: self)
//    }
}
