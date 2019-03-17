// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenInstanceActionViewControllerDelegate: class, CanOpenURL {
    func didPressViewRedemptionInfo(in viewController: TokenInstanceActionViewController)
    func shouldCloseFlow(inViewController viewController: TokenInstanceActionViewController)
}

class TokenInstanceActionViewController: UIViewController, TokenVerifiableStatusViewController {
    static let anArbitaryRowHeightSoAutoSizingCellsWorkIniOS10 = CGFloat(100)

    private let tokenObject: TokenObject
    private let tokenHolder: TokenHolder
    private var viewModel: TokenInstanceActionViewModel
    private let action: TokenInstanceAction
    private let tokensStorage: TokensDataStore
    private let account: Wallet
    private let roundedBackground = RoundedBackground()
    lazy private var tokenScriptRendererView: TokenInstanceWebView = {
        //TODO pass in keystore or wallet address instead
        let walletAddress = try! EtherKeystore().recentlyUsedWallet!.address
        let webView = TokenInstanceWebView(server: server, walletAddress: walletAddress, assetDefinitionStore: assetDefinitionStore)
        webView.isWebViewInteractionEnabled = true
        webView.delegate = self
        return webView
    }()

    //TODO might have to change the number of buttons? if the action type change or should we just go back since the flow may be broken if we remain in this screen
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)

    var server: RPCServer {
        return tokenObject.server
    }
    var contract: String {
        return tokenObject.contract
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: TokenInstanceActionViewControllerDelegate?

    var isReadOnly = false {
        didSet {
            configure()
        }
    }

    var canPeekToken: Bool {
        let tokenType = OpenSeaNonFungibleTokenHandling(token: tokenObject)
        switch tokenType {
        case .supportedByOpenSea:
            return true
        case .notSupportedByOpenSea:
            return false
        }
    }

    init(tokenObject: TokenObject, tokenHolder: TokenHolder, account: Wallet, tokensStorage: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, action: TokenInstanceAction) {
        self.tokenObject = tokenObject
        self.tokenHolder = tokenHolder
        self.account = account
        self.tokensStorage = tokensStorage
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = .init(tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        self.action = action
        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withVerificationType: .unverified)

        view.backgroundColor = Colors.appBackground
		
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        tokenScriptRendererView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(tokenScriptRendererView)

        footerBar.addSubview(buttonsBar)

        let webViewMargin: CGFloat = 20
        NSLayoutConstraint.activate([
            tokenScriptRendererView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tokenScriptRendererView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tokenScriptRendererView.topAnchor.constraint(equalTo: roundedBackground.topAnchor, constant: webViewMargin),
            tokenScriptRendererView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

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

    func configure(viewModel newViewModel: TokenInstanceActionViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withVerificationType: verificationType)

        //TODO this should be from the action which knows what type it is and what buttons to provide. Currently just "Confirm"
        buttonsBar.numberOfButtons = 1
        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        //TODO better localized string, but we do want "Confirm" here
        button.setTitle(R.string.localizable.confirmPaymentConfirmButtonTitle(), for: .normal)
        button.addTarget(self, action: #selector(proceed), for: .touchUpInside)

        tokenScriptRendererView.loadHtml(action.viewHtml)
        tokenScriptRendererView.update(withTokenHolder: tokenHolder, asUserScript: true)
    }

    @objc func proceed() {
        //TODO maybe should be web3.actions.onConfirm() or something?
        tokenScriptRendererView.inject(javaScript: "onConfirm()")
    }

    func showInfo() {
		delegate?.didPressViewRedemptionInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: tokenObject.contract, server: server, in: self)
    }
}

extension TokenInstanceActionViewController: TokenInstanceWebViewDelegate {
    //TODO not good. But quick and dirty to ship
    func navigationControllerFor(tokenInstanceWebView: TokenInstanceWebView) -> UINavigationController? {
        return navigationController
    }

    func shouldClose(tokenInstanceWebView: TokenInstanceWebView) {
        delegate?.shouldCloseFlow(inViewController: self)
    }
}
