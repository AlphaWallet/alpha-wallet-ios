// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit

protocol TokenInstanceActionViewControllerDelegate: class, CanOpenURL {
    func didPressViewRedemptionInfo(in viewController: TokenInstanceActionViewController)
    func shouldCloseFlow(inViewController viewController: TokenInstanceActionViewController)
}

class TokenInstanceActionViewController: UIViewController, TokenVerifiableStatusViewController {
    private let tokenObject: TokenObject
    private let tokenHolder: TokenHolder
    private let viewModel: TokenInstanceActionViewModel
    private let action: TokenInstanceAction
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
        return webView
    }()

    //TODO might have to change the number of buttons? if the action type change or should we just go back since the flow may be broken if we remain in this screen
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
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
        buttonsBar.numberOfButtons = 1
        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        //TODO better localized string, but we do want "Confirm" here
        button.setTitle(R.string.localizable.confirmPaymentConfirmButtonTitle(), for: .normal)
        button.addTarget(self, action: #selector(proceed), for: .touchUpInside)

        tokenScriptRendererView.loadHtml(action.viewHtml)
        tokenScriptRendererView.update(withTokenHolder: tokenHolder, isFungible: isFungible)
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
        let tokenLevelAttributeValues = xmlHandler.resolveAttributesBypassingCache(withTokenId: tokenId, server: server, account: session.account)
        let resolveTokenLevelSubscribableAttributes = Array(tokenLevelAttributeValues.values).filterToSubscribables.createPromiseForSubscribeOnce()

        firstly {
            when(fulfilled: resolveTokenLevelSubscribableAttributes)
        }.then {
            when(fulfilled: fetchUserEntries)
        }.map { (userEntryValues: [Any?]) -> [AttributeId: String] in
            guard let values = userEntryValues as? [String] else { return .init() }
            let zippedIdsAndValues = zip(userEntryIds, values).map { (userEntryId, value) -> (AttributeId, String)? in
                //Should always find a matching attribute
                guard let attribute = self.action.attributes.values.first(where: { $0.userEntryId == userEntryId }) else { return nil }
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
            guard strongSelf.action.contract != nil, let transactionFunction = strongSelf.action.transactionFunction else { return }
            let tokenId = strongSelf.tokenId

            func notify(message: String) {
                UIAlertController.alert(title: message,
                        message: "",
                        alertButtonTitles: [R.string.localizable.oK()],
                        alertButtonStyles: [.default],
                        viewController: strongSelf,
                        completion: nil)
            }

            func postTransaction() {
                transactionFunction.postTransaction(withTokenId: tokenId, attributeAndValues: values, server: strongSelf.server, session: strongSelf.session, keystore: strongSelf.keystore).done {
                    notify(message: "Posted Transaction Successfully")
                }.catch { error in
                    notify(message: "Transaction Failed")
                }
            }

            guard let (data, value) = transactionFunction.generateDataAndValue(withTokenId: tokenId, attributeAndValues: values, server: strongSelf.server, session: strongSelf.session, keystore: strongSelf.keystore) else { return }
            let eth = EtherNumberFormatter.full.string(from: BigInt(value))
            let nativeCryptSymbol: String
            switch strongSelf.server {
            case .xDai:
                nativeCryptSymbol = "xDAI"
            case .artis_sigma1, .artis_tau1:
                nativeCryptSymbol = "ATS"
            case .rinkeby, .ropsten, .main, .custom, .callisto, .classic, .kovan, .sokol, .poa, .goerli:
                nativeCryptSymbol = "ETH"
            }
            if let data = data {
                if value > 0 {
                    UIAlertController.alert(title: "Confirm Transaction?", message: "Data: \(data.hexEncoded)\nAmount: \(eth) \(nativeCryptSymbol)", alertButtonTitles: [R.string.localizable.confirmPaymentConfirmButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: self, preferredStyle: .actionSheet) {
                        guard $0 == 0 else { return }
                        postTransaction()
                    }
                } else {
                    UIAlertController.alert(title: "Confirm Transaction?", message: "Data: \(data.hexEncoded)", alertButtonTitles: [R.string.localizable.confirmPaymentConfirmButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: self, preferredStyle: .actionSheet) {
                        guard $0 == 0 else { return }
                        postTransaction()
                    }
                }
            } else {
                UIAlertController.alert(title: "Confirm Transfer?", message: "Amount: \(eth) \(nativeCryptSymbol)", alertButtonTitles: [R.string.localizable.confirmPaymentConfirmButtonTitle(), R.string.localizable.cancel()], alertButtonStyles: [.default, .cancel], viewController: self, preferredStyle: .actionSheet) {
                    guard $0 == 0 else { return }
                    postTransaction()
                }
            }
        }.cauterize()
        //TODO catch
    }

    private func resolveActionAttributeValues(withUserEntryValues userEntryValues: [AttributeId: String], tokenLevelTokenIdOriginAttributeValues: [AttributeId: AssetAttributeSyntaxValue]) -> Promise<[AttributeId: AssetInternalValue]> {
        return Promise { seal in
            //TODO Not reading/writing from/to cache here because we haven't worked out volatility of attributes yet. So we assume all attributes used by an action as volatile, have to fetch the latest
            let attributeNameValues = action.attributes.resolve(withTokenId: tokenId, userEntryValues: userEntryValues, server: server, account: session.account, additionalValues: tokenLevelTokenIdOriginAttributeValues).mapValues { $0.value }
            var allResolved = false
            let attributes = AssetAttributeValues(attributeValues: attributeNameValues)
            let resolvedAttributeNameValues = attributes.resolve() { updatedValues in
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
}
