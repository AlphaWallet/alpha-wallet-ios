//
//  NFTAssetViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol NonFungibleTokenViewControllerDelegate: class, CanOpenURL {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: NFTAssetViewController)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: NFTAssetViewController)
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: NFTAssetViewController)
    func didPressViewRedemptionInfo(in viewController: NFTAssetViewController)
    func didTapURL(url: URL, in viewController: NFTAssetViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: NFTAssetViewController)
}

class NFTAssetViewController: UIViewController, TokenVerifiableStatusViewController {
    private let analyticsCoordinator: AnalyticsCoordinator
    private (set) var viewModel: NFTAssetViewModel
    private let bigImageView: WebImageView = {
        let imageView = WebImageView()
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()
    private let buttonsBar = HorizontalButtonsBar(configuration: .combined(buttons: 3))
    private lazy var containerView: ScrollableStackView = ScrollableStackView()
    private let mode: TokenInstanceViewMode
    private lazy var attributesStackView = GridStackView(viewModel: .init(edgeInsets: .init(top: 0, left: 20, bottom: 15, right: 20)))

    var server: RPCServer {
        return viewModel.token.server
    }
    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: NonFungibleTokenViewControllerDelegate?

    init(analyticsCoordinator: AnalyticsCoordinator, assetDefinitionStore: AssetDefinitionStore, viewModel: NFTAssetViewModel, mode: TokenInstanceViewMode) {
        self.analyticsCoordinator = analyticsCoordinator
        self.assetDefinitionStore = assetDefinitionStore
        self.mode = mode
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        let stackView = [containerView, footerBar].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view),
            bigImageView.heightAnchor.constraint(equalToConstant: 250),
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //NOTE: Blank out the title before pushing the send screen because longer (not even very long ones) titles will overlay the Send screen's back button
    override func viewWillAppear(_ animated: Bool) {
        title = viewModel.navigationTitle
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
    }

    override func viewWillDisappear(_ animated: Bool) {
        title = ""
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let values = viewModel.tokenHolder.values
        if let openSeaSlug = values.slug, openSeaSlug.trimmed.nonEmpty {
            var viewModel = viewModel
            OpenSea.collectionStats(slug: openSeaSlug, server: viewModel.token.server).done { stats in
                viewModel.configure(overiddenOpenSeaStats: stats)
                self.configure(viewModel: viewModel)
            }.cauterize()
        }
    }

    private func generateSubviews(viewModel: NFTAssetViewModel) {
        let stackView = containerView.stackView
        stackView.removeAllArrangedSubviews()

        var subviews: [UIView] = [bigImageView]

        for (index, each) in viewModel.configurations.enumerated() {
            switch each {
            case .header(let viewModel):
                let header = TokenInfoHeaderView(edgeInsets: .init(top: 15, left: 15, bottom: 20, right: 0))
                header.configure(viewModel: viewModel)

                subviews.append(header)
            case .field(let viewModel):
                let view = TokenInstanceAttributeView(indexPath: IndexPath(row: index, section: 0))
                view.configure(viewModel: viewModel)
                view.delegate = self

                subviews.append(view)
            case .attributeCollection(let viewModel):
                var views: [UIView] = []
                for (row, attribute) in viewModel.traits.enumerated() {
                    let view = NonFungibleTraitView(edgeInsets: .init(top: 10, left: 10, bottom: 10, right: 10), indexPath: IndexPath(row: row, section: index))
                    view.configure(viewModel: attribute)

                    views.append(view)
                }
                attributesStackView.set(subviews: views)

                subviews.append(attributesStackView)
            }
        }

        stackView.addArrangedSubviews(subviews)
    }

    func configure(viewModel newViewModel: NFTAssetViewModel) {
        viewModel = newViewModel

        view.backgroundColor = viewModel.backgroundColor
        containerView.backgroundColor = viewModel.backgroundColor
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)
        title = viewModel.navigationTitle

        switch mode {
        case .preview:
            buttonsBar.configure(.empty)
        case .interactive:
            buttonsBar.configure(.combined(buttons: viewModel.actions.count))
            buttonsBar.viewController = self

            func _configButton(action: TokenInstanceAction, button: BarButton) {
                if let selection = action.activeExcludingSelection(selectedTokenHolders: [viewModel.tokenHolder], forWalletAddress: viewModel.account.address) {
                    if selection.denial == nil {
                        button.displayButton = false
                    }
                }
            }

            for (index, button) in buttonsBar.buttons.enumerated() {
                let action = viewModel.actions[index]
                button.setTitle(action.name, for: .normal)
                button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
                switch viewModel.account.type {
                case .real:
                    _configButton(action: action, button: button)
                case .watch:
                    //TODO pass in a Config instance instead
                    if Config().development.shouldPretendIsRealWallet {
                        _configButton(action: action, button: button)
                    } else {
                        button.isEnabled = false
                    }
                }
            }
        }

        bigImageView.setImage(url: viewModel.tokenHolder.assetImageUrl(tokenId: viewModel.tokenId), placeholder: viewModel.tokenImagePlaceholder)

        generateSubviews(viewModel: viewModel)
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .nftRedeem:
                redeem()
            case .nftSell:
                sell()
            case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
                //TODO when we support TokenScript views for ERC20s, we need to perform the action here
                break
            case .nonFungibleTransfer:
                transfer()
            case .tokenScript:
                if let selection = action.activeExcludingSelection(selectedTokenHolder: viewModel.tokenHolder, tokenId: viewModel.tokenId, forWalletAddress: viewModel.account.address) {
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
                    delegate?.didTap(action: action, tokenHolder: viewModel.tokenHolder, viewController: self)
                }
            }
            break
        }
    }

    private func transfer() {
        delegate?.didPressTransfer(token: viewModel.token, tokenHolder: viewModel.tokenHolder, forPaymentFlow: .send(type: .transaction(viewModel.transferTransactionType)), in: self)
    }

    private func redeem() {
        delegate?.didPressRedeem(token: viewModel.token, tokenHolder: viewModel.tokenHolder, in: self)
    }

    private func sell() {
        delegate?.didPressSell(tokenHolder: viewModel.tokenHolder, for: .send(type: .transaction(viewModel.sellTransactionType)), in: self)
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

extension NFTAssetViewController: TokenInstanceAttributeViewDelegate {
    func didSelect(in view: TokenInstanceAttributeView) {
        switch viewModel.configurations[view.indexPath.row] {
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
