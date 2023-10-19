// Copyright © 2018 Stormbird PTE. LTD.

import Combine
import Foundation
import UIKit
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletTokenScript
import BigInt
import PromiseKit

protocol TokenInstanceActionViewControllerDelegate: AnyObject, CanOpenURL, RequestSignMessageDelegate {
    func didPressViewRedemptionInfo(in viewController: TokenInstanceActionViewController)
    func shouldCloseFlow(inViewController viewController: TokenInstanceActionViewController)
    func didClose(in viewController: TokenInstanceActionViewController)
}

class TokenInstanceActionViewController: UIViewController, TokenVerifiableStatusViewController {
    private let analytics: AnalyticsLogger
    private let token: Token
    private let tokenHolder: TokenHolder
    private let action: TokenInstanceAction
    private let session: WalletSession
    private let keystore: Keystore
    private let roundedBackground = RoundedBackground()
    private lazy var tokenScriptRendererView: TokenScriptWebView = {
        //TODO pass in Config instance instead
        let webView = TokenScriptWebView(server: server, serverWithInjectableRpcUrl: server, wallet: session.account.type, assetDefinitionStore: assetDefinitionStore, shouldPretendIsRealWallet: Config().development.shouldPretendIsRealWallet)
        webView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        webView.isWebViewInteractionEnabled = true
        webView.delegate = self
        webView.isStandalone = true

        return webView
    }()

    //TODO might have to change the number of buttons? if the action type change or should we just go back since the flow may be broken if we remain in this screen
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var isFungible: Bool {
        switch token.type {
        case .nativeCryptocurrency:
            return true
        case .erc20:
            return true
        case .erc721, .erc1155:
            return false
        case .erc875:
            return false
        case .erc721ForTickets:
            return false
        }
    }

    var server: RPCServer {
        return token.server
    }
    var contract: AlphaWallet.Address {
        return token.contractAddress
    }
    var tokenId: TokenId {
        return tokenHolder.tokens[0].id
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: (TokenInstanceActionViewControllerDelegate & ConfirmTokenScriptActionTransactionDelegate)?

    var canPeekToken: Bool {
        let tokenType = NonFungibleFromJsonSupportedTokenHandling(token: token)
        switch tokenType {
        case .supported:
            return true
        case .notSupported:
            return false
        }
    }

    init(analytics: AnalyticsLogger, token: Token, tokenHolder: TokenHolder, assetDefinitionStore: AssetDefinitionStore, action: TokenInstanceAction, session: WalletSession, keystore: Keystore) {
        self.analytics = analytics
        self.token = token
        self.tokenHolder = tokenHolder
        self.assetDefinitionStore = assetDefinitionStore
        self.action = action
        self.session = session
        self.keystore = keystore
        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

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
            buttonsBar.heightAnchor.constraint(equalToConstant: HorizontalButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -HorizontalButtonsBar.buttonsHeight - HorizontalButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        //TODO this should be from the action which knows what type it is and what buttons to provide. Currently just "Confirm"
        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        //TODO better localized string, but we do want "Confirm" here
        button.setTitle(R.string.localizable.confirmPaymentConfirmButtonTitle(), for: .normal)
        button.addTarget(self, action: #selector(proceed), for: .touchUpInside)

        let tokenScriptView = action.viewHtml(tokenId: tokenHolder.tokenIds[0])
        tokenScriptRendererView.loadHtml(tokenScriptView.html, urlFragment: tokenScriptView.urlFragment)

        //TODO this will only contain values that has been resolved and might not refresh properly when the values are 1st resolved or updated
        //TODO rename this. Not actually `existingAttributeValues`, but token attributes
        let existingAttributeValues = tokenHolder.values
        //TODO why does this resolution not go through an XMLHandler?
        let cardLevelAttributeValues = assetDefinitionStore
            .assetAttributeResolver
            .resolve(withTokenIdOrEvent: tokenHolder.tokens[0].tokenIdOrEvent,
                     userEntryValues: .init(),
                     server: server,
                     account: session.account.address,
                     additionalValues: existingAttributeValues,
                     localRefs: tokenScriptRendererView.localRefs,
                     attributes: action.attributes)

        tokenScriptRendererView.update(withTokenHolder: tokenHolder, cardLevelAttributeValues: cardLevelAttributeValues, isFungible: isFungible)
    }

    @objc func proceed() {
        let javaScriptToCallConfirm = """
                                      if (window.onConfirm != null) {
                                        onConfirm()
                                      }
                                      """
        tokenScriptRendererView.inject(javaScript: javaScriptToCallConfirm)
        let userEntryIds = action.attributes.values.compactMap { $0.userEntryId }
        let fetchUserEntries = userEntryIds
            .map { "document.getElementById(\"\($0)\").value" }
            .compactMap { tokenScriptRendererView.inject(javaScript: $0) }
        guard let navigationController = navigationController else { return }

        TokenScript.performTokenScriptAction(action, token: token, tokenId: tokenId, tokenHolder: tokenHolder, userEntryIds: userEntryIds, fetchUserEntries: fetchUserEntries, localRefsSource: tokenScriptRendererView, assetDefinitionStore: assetDefinitionStore, keystore: keystore, server: server, session: session, confirmTokenScriptActionTransactionDelegate: self, navigationController: navigationController)
    }
}

extension TokenInstanceActionViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewRedemptionInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: token.contractAddress, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension TokenInstanceActionViewController: TokenScriptWebViewDelegate {
    func requestSignMessage(message: SignMessageType, server: RPCServer, account: AlphaWallet.Address, inTokenScriptWebView tokenScriptWebView: TokenScriptWebView) -> AnyPublisher<Data, PromiseError> {
        guard let delegate = delegate else { return .empty() }
        return delegate.requestSignMessage(message: message, server: server, account: account, source: .tokenScript, requester: nil)
    }

    func shouldClose(tokenScriptWebView: TokenScriptWebView) {
        //Bit of delay to wait for the UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            SuccessOverlayView.show()
        }
        delegate?.shouldCloseFlow(inViewController: self)
    }

    func reinject(tokenScriptWebView: TokenScriptWebView) {
        configure()
    }
}

extension TokenInstanceActionViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension TokenInstanceActionViewController: ConfirmTokenScriptActionTransactionDelegate {
    func confirmTransactionSelected(in navigationController: UINavigationController, token: Token, contract: AlphaWallet.Address, tokenId: TokenId, values: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore, transactionFunction: FunctionOrigin) {
        delegate?.confirmTransactionSelected(in: navigationController, token: token, contract: contract, tokenId: tokenId, values: values, localRefs: localRefs, server: server, session: session, keystore: keystore, transactionFunction: transactionFunction)
    }
}
