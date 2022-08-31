//
//  TokenCardRedemptionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit
import AlphaWalletFoundation

protocol TokenCardRedemptionViewControllerDelegate: class, CanOpenURL {
}

class TokenCardRedemptionViewController: UIViewController, TokenVerifiableStatusViewController {
    private var viewModel: TokenCardRedemptionViewModel
    private let scrollView = UIScrollView()
    private var titleLabel = UILabel()
    private let imageView =  UIImageView()
    private let tokenRowView: TokenRowView & UIView
    private var timer: Timer!
    private var session: WalletSession
    private let token: Token
    private let analytics: AnalyticsLogger
    private let keystore: Keystore

    var contract: AlphaWallet.Address {
        return token.contractAddress
    }
    var server: RPCServer {
        return token.server
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: TokenCardRedemptionViewControllerDelegate?

    init(session: WalletSession, token: Token, viewModel: TokenCardRedemptionViewModel, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, keystore: Keystore) {
		self.session = session
        self.token = token
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.keystore = keystore

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        switch tokenType {
        case .backedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notBackedByOpenSea:
            tokenRowView = TokenCardRowView(analytics: analytics, server: token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, keystore: keystore, wallet: session.account)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        imageView.translatesAutoresizingMaskIntoConstraints = false

        let imageHolder = UIView()
        imageHolder.translatesAutoresizingMaskIntoConstraints = false
        imageHolder.backgroundColor = Colors.appWhite
        imageHolder.cornerRadius = Metrics.CornerRadius.box
        imageHolder.addSubview(imageView)

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            .spacer(height: 16),
            titleLabel,
            .spacer(height: 8),
            imageHolder,
            .spacer(height: 4),
            tokenRowView,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            imageView.leadingAnchor.constraint(equalTo: imageHolder.leadingAnchor, constant: 64),
            imageView.trailingAnchor.constraint(equalTo: imageHolder.trailingAnchor, constant: -64),
            imageView.topAnchor.constraint(equalTo: imageHolder.topAnchor, constant: 16),
            imageView.bottomAnchor.constraint(equalTo: imageHolder.bottomAnchor, constant: -16),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor),

            imageHolder.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            imageHolder.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            tokenRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.anchorsConstraint(to: view),

            stackView.anchorsConstraint(to: scrollView),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func configureUI() {
        let redeem = CreateRedeem(token: token)
        let redeemData: (message: String, qrCode: String)
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc1155:
            return
        case .erc875:
            redeemData = redeem.redeemMessage(indices: viewModel.tokenHolder.indices)
        case .erc721, .erc721ForTickets:
            redeemData = redeem.redeemMessage(tokenIds: viewModel.tokenHolder.tokens.map({ $0.id }))
        }
        func _generateQr(account: AlphaWallet.Address) {
            do {
                let prompt = R.string.localizable.keystoreAccessKeySign()
                guard let decimalSignature = try SignatureHelper.signatureAsDecimal(for: redeemData.message, account: account, keystore: keystore, prompt: prompt) else { return }
                let qrCodeInfo = redeemData.qrCode + decimalSignature
                imageView.image = qrCodeInfo.toQRCode()
            } catch {
                //no-op
            }
        }
        switch session.account.type {
        case .real(let account):
            _generateQr(account: account)
        case .watch(let account):
            //TODO should pass in a Config instance instead
            if Config().development.shouldPretendIsRealWallet {
                _generateQr(account: account)
            } else {
                //no-op
            }
        }
    }

    private func showSuccessMessage() {
        invalidateTimer()

        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
        UIAlertController.alert(title: R.string.localizable.aWalletTokenRedeemSuccessfulTitle(),
                                message: R.string.localizable.aWalletTokenRedeemSuccessfulDescription(tokenTypeName),
                                alertButtonTitles: [R.string.localizable.oK()],
                                alertButtonStyles: [.cancel],
                                viewController: self,
                                completion: { [weak self] _ in
                                    guard let strongSelf = self else { return }
                                    // TODO: let token coordinator handle this as we need to refresh the token list as well
                                    strongSelf.dismiss(animated: true, completion: nil)
                                })

    }

    private func invalidateTimer() {
        if timer.isValid {
            timer.invalidate()
        }
    }

    func configure(viewModel newViewModel: TokenCardRedemptionViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        view.backgroundColor = viewModel.backgroundColor

        titleLabel.textAlignment = .center
        titleLabel.textColor = viewModel.headerColor
        titleLabel.font = viewModel.headerFont
        titleLabel.numberOfLines = 0
        titleLabel.text = viewModel.headerTitle

        configureUI()

        tokenRowView.configure(tokenHolder: viewModel.tokenHolder)

        tokenRowView.stateLabel.isHidden = true
    }
}

extension TokenCardRedemptionViewController: VerifiableStatusViewController {
    func showInfo() {
        let controller = TokenCardRedemptionInfoViewController(delegate: self)
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(controller, animated: true)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: viewModel.token.contractAddress, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension TokenCardRedemptionViewController: StaticHTMLViewControllerDelegate {
}

extension TokenCardRedemptionViewController: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
