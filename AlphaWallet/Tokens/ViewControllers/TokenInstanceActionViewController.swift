// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit

protocol TokenInstanceActionViewControllerDelegate: class, CanOpenURL {
    func didPressViewRedemptionInfo(in viewController: TokenInstanceActionViewController)
    func shouldCloseFlow(inViewController viewController: TokenInstanceActionViewController)
    func didCompleteTransaction(in viewController: TokenInstanceActionViewController)
}

class TokenInstanceActionViewController: UIViewController, TokenVerifiableStatusViewController {
    private let tokenObject: TokenObject
    private let tokenHolder: TokenHolder
    private let viewModel: TokenInstanceActionViewModel
    //TODO fix for activities: So we switch to the aEth token after action
    let action: TokenInstanceAction
    private let session: WalletSession
    private let keystore: Keystore
    private let tokensStorage: TokensDataStore
    private let roundedBackground = RoundedBackground()
    lazy private var tokenScriptRendererView: TokenInstanceWebView = {
        //TODO pass in keystore or wallet address instead
        let walletAddress = EtherKeystore.current!.address
        let webView = TokenInstanceWebView(server: server, walletAddress: walletAddress, assetDefinitionStore: assetDefinitionStore)
        webView.isWebViewInteractionEnabled = true
        webView.delegate = self
        webView.isStandalone = true
        webView.isAction = true
        return webView
    }()


    //TODO might have to change the number of buttons? if the action type change or should we just go back since the flow may be broken if we remain in this screen
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var isFungible: Bool {
        switch tokenObject.type {
        case .nativeCryptocurrency:
            return true
        case .erc20:
            return true
        case .erc721:
            return false
        case .erc875:
            return false
        case .erc721ForTickets:
            return false
        }
    }

    var server: RPCServer {
        return tokenObject.server
    }
    var contract: AlphaWallet.Address {
        return tokenObject.contractAddress
    }
    var tokenId: TokenId {
        return tokenHolder.tokens[0].id
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: TokenInstanceActionViewControllerDelegate?

    var isReadOnly = false {
        didSet {
            configure()
        }
    }

    var canPeekToken: Bool {
        let tokenType = OpenSeaSupportedNonFungibleTokenHandling(token: tokenObject)
        switch tokenType {
        case .supportedByOpenSea:
            return true
        case .notSupportedByOpenSea:
            return false
        }
    }

    init(tokenObject: TokenObject, tokenHolder: TokenHolder, tokensStorage: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, action: TokenInstanceAction, session: WalletSession, keystore: Keystore) {
        self.tokenObject = tokenObject
        self.tokenHolder = tokenHolder
        self.tokensStorage = tokensStorage
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = .init(tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        self.action = action
        self.session = session
        self.keystore = keystore
        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

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

    func configure() {
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        //TODO this should be from the action which knows what type it is and what buttons to provide. Currently just "Confirm"
        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        //TODO better localized string, but we do want "Confirm" here
        button.setTitle(R.string.localizable.confirmPaymentConfirmButtonTitle(), for: .normal)
        button.addTarget(self, action: #selector(proceed), for: .touchUpInside)

        let (html: html, hash: hash) = action.viewHtml(forTokenHolder: tokenHolder)
        tokenScriptRendererView.loadHtml(html, hash: hash)

        //TODO this will only contain values that has been resolved and might not refresh properly when the values are 1st resolved or updated
        //TODO rename this. Not actually `existingAttributeValues`, but token attributes
        let existingAttributeValues = tokenHolder.values
        let cardLevelAttributeValues = action.attributes.resolve(withTokenIdOrEvent: tokenHolder.tokens[0].tokenIdOrEvent, userEntryValues: .init(), server: server, account: session.account, additionalValues: existingAttributeValues, localRefs: tokenScriptRendererView.localRefs)

        tokenScriptRendererView.update(withTokenHolder: tokenHolder, cardLevelAttributeValues: cardLevelAttributeValues, isFungible: isFungible)
    }

    @objc func proceed() {
        let javaScriptToCallConfirm = """
                                      if (window.onConfirm != null) {
                                        onConfirm()
                                      }
                                      """
        tokenScriptRendererView.inject(javaScript: javaScriptToCallConfirm)

        guard action.hasTransactionFunction else { return }

        let userEntryIds = action.attributes.values.compactMap { $0.userEntryId }
        let fetchUserEntries = userEntryIds
                .map { "document.getElementById(\"\($0)\").value" }
                .compactMap { tokenScriptRendererView.inject(javaScript: $0) }
        let xmlHandler = XMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore)
        let tokenLevelAttributeValues = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: tokenHolder.tokens[0].tokenIdOrEvent, server: server, account: session.account)
        let resolveTokenLevelSubscribableAttributes = Array(tokenLevelAttributeValues.values).filterToSubscribables.createPromiseForSubscribeOnce()

        firstly {
            when(fulfilled: resolveTokenLevelSubscribableAttributes)
        }.then {
            when(fulfilled: fetchUserEntries)
        }.map { (userEntryValues: [Any?]) -> [AttributeId: String] in
            guard let values = userEntryValues as? [String] else { return .init() }
            let zippedIdsAndValues = zip(userEntryIds, values).map { (userEntryId, value) -> (AttributeId, String)? in
                //Should always find a matching attribute
                guard self.action.attributes.values.first(where: { $0.userEntryId == userEntryId }) != nil else { return nil }
                return (userEntryId, value)
            }.compactMap { $0 }
            return Dictionary(uniqueKeysWithValues: zippedIdsAndValues)
        }.then { userEntryValues -> Promise<[AttributeId: AssetInternalValue]> in
            //Make sure to resolve every attribute before actionsheet appears without hitting the cache. Both action and token-level attributes (especially function-origins)
            //TODO also have to monitor for changes to the attributes, be able to flag it and update actionsheet. Maybe just a matter of getting a list of AssetAttributes and their subscribables (AssetInternalValue?), subscribing to them so that we can indicate changes?
            let (_, tokenIdBased) = tokenLevelAttributeValues.splitAttributesIntoSubscribablesAndNonSubscribables
            return self.resolveActionAttributeValues(withUserEntryValues: userEntryValues, tokenLevelTokenIdOriginAttributeValues: tokenIdBased)
        }.map { (values: [AttributeId: AssetInternalValue]) -> [AttributeId: AssetInternalValue] in
            //Force unwrap because we know they have been resolved earlier in this promise chain
            let allAttributesAndValues = values.merging(tokenLevelAttributeValues.mapValues { $0.value.resolvedValue! }) { (_, new) in new }
            return allAttributesAndValues
        }.done { values in
            let strongSelf = self
            guard let contract = strongSelf.action.contract, let transactionFunction = strongSelf.action.transactionFunction else { return }
            let tokenId = strongSelf.tokenId

            func notify(message: String) {
                UIAlertController.alert(title: message,
                    message: "",
                    alertButtonTitles: [R.string.localizable.oK()],
                    alertButtonStyles: [.default],
                    viewController: strongSelf,
                    completion: nil
                )
            }

            func postTransaction() {
                transactionFunction.postTransaction(withTokenId: tokenId, attributeAndValues: values, localRefs: strongSelf.tokenScriptRendererView.localRefs, server: strongSelf.server, session: strongSelf.session, keystore: strongSelf.keystore).done {
                    strongSelf.delegate?.didCompleteTransaction(in: strongSelf)
                }.catch { error in
                    notify(message: "Transaction Failed")
                }
            }

            guard transactionFunction.generateDataAndValue(withTokenId: tokenId, attributeAndValues: values, localRefs: strongSelf.tokenScriptRendererView.localRefs, server: strongSelf.server, session: strongSelf.session, keystore: strongSelf.keystore) != nil else { return }

            guard let navigationController = strongSelf.navigationController else { return }

            let viewModel = TransactionConfirmationViewModel(contract: contract)
            let controller = TransactionConfirmationViewController(viewModel: viewModel)
            controller.didCompleted = postTransaction

            let transitionController = ConfirmationTransitionController(sourceViewController: navigationController, destinationViewController: controller)
            transitionController.start()

        }.cauterize()
        //TODO catch
    }

    private func resolveActionAttributeValues(withUserEntryValues userEntryValues: [AttributeId: String], tokenLevelTokenIdOriginAttributeValues: [AttributeId: AssetAttributeSyntaxValue]) -> Promise<[AttributeId: AssetInternalValue]> {
        return Promise { seal in
            //TODO Not reading/writing from/to cache here because we haven't worked out volatility of attributes yet. So we assume all attributes used by an action as volatile, have to fetch the latest
            //Careful to only resolve (and wait on) attributes that the smart contract function invocation is dependent on. Some action-level attributes might only be used for display
            let attributeNameValues = action.attributesDependencies.resolve(withTokenIdOrEvent: tokenHolder.tokens[0].tokenIdOrEvent, userEntryValues: userEntryValues, server: server, account: session.account, additionalValues: tokenLevelTokenIdOriginAttributeValues, localRefs: tokenScriptRendererView.localRefs).mapValues { $0.value }
            var allResolved = false
            let attributes = AssetAttributeValues(attributeValues: attributeNameValues)
            let resolvedAttributeNameValues = attributes.resolve { updatedValues in
                guard !allResolved && attributes.isAllResolved else { return }
                allResolved = true
                seal.fulfill(updatedValues)
            }
            allResolved = attributes.isAllResolved
            if allResolved {
                seal.fulfill(resolvedAttributeNameValues)
            }
        }
    }
}

extension TokenInstanceActionViewController: VerifiableStatusViewController {
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

extension TokenInstanceActionViewController: TokenInstanceWebViewDelegate {
    //TODO not good. But quick and dirty to ship
    func navigationControllerFor(tokenInstanceWebView: TokenInstanceWebView) -> UINavigationController? {
        return navigationController
    }

    func shouldClose(tokenInstanceWebView: TokenInstanceWebView) {
        //Bit of delay to wait for the UI animation to almost finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            SuccessOverlayView.show()
        }
        delegate?.shouldCloseFlow(inViewController: self)
    }

    func heightChangedFor(tokenInstanceWebView: TokenInstanceWebView) {
        //no-op. Auto layout handles it
    }

    func reinject(tokenInstanceWebView: TokenInstanceWebView) {
        configure()
    }
}
