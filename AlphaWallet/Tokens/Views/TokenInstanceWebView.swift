// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit
import WebKit
import Combine
import AlphaWalletFoundation

protocol TokenInstanceWebViewDelegate: AnyObject {
    //TODO not good. But quick and dirty to ship
    func navigationControllerFor(tokenInstanceWebView: TokenInstanceWebView) -> UINavigationController?
    func shouldClose(tokenInstanceWebView: TokenInstanceWebView)
    func reinject(tokenInstanceWebView: TokenInstanceWebView)
}

class TokenInstanceWebView: UIView {
    var coordinators: [Coordinator] = []

    private let analytics: AnalyticsLogger
    //TODO see if we can be smarter about just subscribing to the attribute once. Note that this is not `Subscribable.subscribeOnce()`
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private var hashOfCurrentHtml: Int?
    private var hashOfLoadedHtml: Int?
    lazy private var heightConstraint = heightAnchor.constraint(equalToConstant: 100)
    lazy private var webView: WKWebView = {
        let webViewConfig = WKWebViewConfiguration.make(forType: .tokenScriptRenderer, address: wallet.address, in: ScriptMessageProxy(delegate: self))
        webViewConfig.websiteDataStore = .default()
        return .init(frame: .init(x: 0, y: 0, width: 40, height: 40), configuration: webViewConfig)
    }()
    //Used to track asynchronous calls are called for correctly
    private var loadId: Int?
    private var lastInjectedJavaScript: String?
    //TODO remove once we refactor internals to include a TokenScriptContext
    private var lastTokenHolder: TokenHolder?
    var actionProperties: TokenScript.SetProperties.Properties = .init()
    private var lastCardLevelAttributeValues: [AttributeId: AssetAttributeSyntaxValue]?
    private let keystore: Keystore

    var server: RPCServer
    var isWebViewInteractionEnabled: Bool = false {
        didSet {
            webView.isUserInteractionEnabled = isWebViewInteractionEnabled
        }
    }
    weak var delegate: TokenInstanceWebViewDelegate?
    //HACK: Flag necessary to inject token values somewhat reliably in at least 2 distinct cases:
    //A. TokenScript views in token cards (ie. view iconified)
    //B. Action views
    //TODO improve further. It's not reliable enough
    var isStandalone = false

    var isAction = false

    var localRefs: [AttributeId: AssetInternalValue] {
        var results: [AttributeId: AssetInternalValue] = .init()
        for (key, value) in actionProperties {
            if let string = value as? String {
                results[key] = .string(string)
            } else if let int = value as? Int {
                results[key] = .int(BigInt(int))
            }
        }
        return results
    }
    private var cancelable = Set<AnyCancellable>()

    init(analytics: AnalyticsLogger, server: RPCServer, wallet: Wallet, assetDefinitionStore: AssetDefinitionStore, keystore: Keystore) {
        self.analytics = analytics
        self.server = server
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.keystore = keystore
        super.init(frame: .zero)

        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        let scrollView = webView.scrollView

        scrollView
            .publisher(for: \.contentSize, options: [.new, .initial])
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.heightConstraint.constant = scrollView.contentSize.height
            }.store(in: &cancelable)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self),
            heightConstraint,
        ])
        
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func stopLoading() {
        webView.stopLoading()
    }

    //Implementation: String concatenation is slow, but it's not obvious at all
    func update(withTokenHolder tokenHolder: TokenHolder, cardLevelAttributeValues updatedCardLevelAttributeValues: [AttributeId: AssetAttributeSyntaxValue]? = nil, isFungible: Bool, isFirstUpdate: Bool = true) {
        lastTokenHolder = tokenHolder
        let unresolvedAttributesDependentOnProps = self.unresolvedAttributesDependentOnProps(tokenHolder: tokenHolder)

        let cardLevelAttributeValues = (updatedCardLevelAttributeValues ?? lastCardLevelAttributeValues) ?? .init()
        lastCardLevelAttributeValues = cardLevelAttributeValues
        var tokenData = [AttributeId: String]()
        tokenData["_count"] = String(tokenHolder.count)

        //TODO We are stuffing the props-dependent attributes into lastCardLevelAttributeValues. Should not be doing this as it's not intention revealing and wrong. But scope-wise, is it wrong? Because these attributes can only be card-level, not token-level, right?
        if lastCardLevelAttributeValues != nil {
            lastCardLevelAttributeValues = lastCardLevelAttributeValues?.merging(unresolvedAttributesDependentOnProps) { _, new in new }
        } else {
            lastCardLevelAttributeValues = unresolvedAttributesDependentOnProps
        }

        let tokenAttributeValues: AssetAttributeValues
        let cardAttributeValues: AssetAttributeValues
        tokenAttributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        cardAttributeValues = AssetAttributeValues(attributeValues: unresolvedAttributesDependentOnProps.merging(cardLevelAttributeValues, uniquingKeysWith: { _, new in new }))

        let resolvedTokenAttributeNameValues = tokenAttributeValues.resolve { [weak self] _ in
            guard let strongSelf = self else { return }
            guard isFirstUpdate else { return }
            strongSelf.update(withTokenHolder: tokenHolder, isFungible: isFungible, isFirstUpdate: false)
        }.merging(implicitAttributes(tokenHolder: tokenHolder, isFungible: isFungible)) { (_, new) in new }

        let resolvedCardAttributeNameValues = cardAttributeValues.resolve { [weak self] _ in
            guard let strongSelf = self else { return }
            guard isFirstUpdate else { return }
            strongSelf.update(withTokenHolder: tokenHolder, isFungible: isFungible, isFirstUpdate: false)
        }

        update(withId: tokenHolder.tokenIds[0], resolvedTokenAttributeNameValues: resolvedTokenAttributeNameValues, resolvedCardAttributeNameValues: resolvedCardAttributeNameValues, isFirstUpdate: isFirstUpdate)
    }

    func update(withId id: BigUInt, resolvedTokenAttributeNameValues: [AttributeId: AssetInternalValue], resolvedCardAttributeNameValues: [AttributeId: AssetInternalValue], isFirstUpdate: Bool = true) {
        var tokenData = [AttributeId: String]()
        let convertor = AssetAttributeToJavaScriptConvertor()
        for (name, value) in resolvedTokenAttributeNameValues {
            if let value = convertor.formatAsTokenScriptJavaScript(value: value) {
                tokenData[name] = value
            }
        }
        var cardData = [AttributeId: String]()
        for (name, value) in resolvedCardAttributeNameValues {
            if let value = convertor.formatAsTokenScriptJavaScript(value: value) {
                cardData[name] = value
            }
        }

        let tokenDataString = tokenData.map { name, value in "\(name): \(value)," }.joined()
        let cardDataString = cardData.map { name, value in "\(name): \(value)," }.joined()
        //TODO remove this soon since it's no longer in the JavaScript API
        let combinedData = tokenData.merging(cardData, uniquingKeysWith: { _, new in new })
        let combinedDataString = combinedData.map { name, value in "\(name): \(value)," }.joined()

        var string = "\nweb3.tokens.data.currentInstance = {\n"
        string += combinedDataString
        string += "\n}"

        string += "\nweb3.tokens.data.token = {\n"
        string += tokenDataString
        string += "\n}"

        string += "\nweb3.tokens.data.card = {\n"
        string += cardDataString
        string += "\n}"

        //TODO include attribute type definitions
//        var attributes = "{"
//        //TODO this seems wrong? Should we remove name and symbol? See the API spec
//        attributes += "name: {value: \"\(tokenHolder.name)\"}, "
//        attributes += "symbol: {value: \"\(tokenHolder.symbol)\"}, "
//        for (id, name) in xmlHandler.fieldIdsAndNames {
//            attributes += "\(id): {name: \"\(name)\"}, "
//        }
//        attributes += "}"
//        string += "\nweb3.tokens.definition = {"
//        string += "\n\"\(contractAddressAsEip55(tokenHolder.contractAddress))\": {"
//        string += "\nattributes: \(attributes)"
//        string += "\n}"
//        string += "\n}"

        let containerCssId = generateContainerCssId(forTokenId: id)
        string += """
                  \nweb3.tokens.dataChanged(old, web3.tokens.data, "\(containerCssId)")
                  """
        let javaScript = """
                         console.log(`update() ran`)
                         const old = web3.tokens.data
                         """ + string

        //Important to inject JavaScript differently depending on whether this is the first time it's loaded because the HTML document may not be ready yet. Seems like it is necessary for `afterDocumentIsLoaded` to always be true here in order to avoid `Can't find variable: web3` errors when used for token cards
        if isStandalone {
            inject(javaScript: javaScript, afterDocumentIsLoaded: isFirstUpdate)
        } else {
            inject(javaScript: javaScript, afterDocumentIsLoaded: true)
        }
    }

    private func unresolvedAttributesDependentOnProps(tokenHolder: TokenHolder) -> [AttributeId: AssetAttributeSyntaxValue] {
        guard !localRefs.isEmpty else { return .init() }
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore)
        let attributes = xmlHandler.fields.filter { $0.value.isDependentOnProps && lastCardLevelAttributeValues?[$0.key] == nil }
        return attributes.resolve(withTokenIdOrEvent: .tokenId(tokenId: tokenHolder.tokenIds[0]), userEntryValues: .init(), server: server, account: wallet, additionalValues: .init(), localRefs: localRefs)
    }

    private func implicitAttributes(tokenHolder: TokenHolder, isFungible: Bool) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        for each in AssetImplicitAttributes.allCases {
            guard each.shouldInclude(forAddress: tokenHolder.contractAddress, isFungible: isFungible) else { continue }
            switch each {
            case .ownerAddress:
                results[each.javaScriptName] = .address(wallet.address)
            case .tokenId:
                results[each.javaScriptName] = .uint(tokenHolder.tokens[0].id)
            case .label:
                let localizedNameFromAssetDefinition = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore).getLabel(fallback: tokenHolder.name)
                results[each.javaScriptName] = .string(localizedNameFromAssetDefinition)
            case .symbol:
                results[each.javaScriptName] = .string(tokenHolder.symbol)
            case .contractAddress:
                results[each.javaScriptName] = .address(tokenHolder.contractAddress)
            }
        }
        return results
    }

    @discardableResult func inject(javaScript: String, afterDocumentIsLoaded: Bool = false) -> Promise<Any?>? {
        if let lastInjectedJavaScript = lastInjectedJavaScript, lastInjectedJavaScript == javaScript {
            return nil
        } else {
            lastInjectedJavaScript = javaScript
        }

        let javaScriptWrappedInScope = """
                                       {
                                          \(javaScript)
                                       }
                                       """
        if afterDocumentIsLoaded {
            let userScript = WKUserScript(source: javaScriptWrappedInScope, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            webView.configuration.userContentController.addUserScript(userScript)
            return nil
        } else {
            return Promise { seal in
                webView.evaluateJavaScript(javaScriptWrappedInScope) { something, error in
                    if let error = error {
                        seal.reject(error)
                    } else {
                        seal.fulfill(something)
                    }
                }
            }
        }
    }

    func loadHtml(_ html: String, hash: Int) {
        hashOfCurrentHtml = hash
        webView.loadHTMLString(html, baseURL: nil)
        hashOfLoadedHtml = hashOfCurrentHtml
    }
}

extension TokenInstanceWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch Browser.MessageType.fromMessage(message) {
        case .some(.dappAction(let command)):
            handleCommandForDappAction(command)
        case .some(.setActionProps(.action(let id, let changedProperties))):
            handleSetActionProperties(id: id, changedProperties: changedProperties)
        case .none:
            break
        }
    }

    private func handleSetActionProperties(id: Int, changedProperties: TokenScript.SetProperties.Properties) {
        guard !changedProperties.isEmpty else { return }
        let oldProperties = actionProperties

        let errorMessage = checkPropsNameClashErrorWithCardAttributes()

        notifyTokenScriptFinish(callbackID: id, errorMessage: errorMessage)
        guard errorMessage == nil else { return }

        for (key, value) in changedProperties {
            actionProperties[key] = value
        }

        guard let oldJsonString = oldProperties.jsonString, let newJsonString = actionProperties.jsonString, oldJsonString != newJsonString else { return }
        if lastCardLevelAttributeValues != nil {
            delegate?.reinject(tokenInstanceWebView: self)
        }
    }

    private func checkPropsNameClashErrorWithCardAttributes() -> String? {
        guard let lastTokenHolder = lastTokenHolder else { return nil }
        let xmlHandler = XMLHandler(contract: lastTokenHolder.contractAddress, tokenType: lastTokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore)
        let attributes = xmlHandler.fields
        let attributeIds: [AttributeId]
        if let lastCardLevelAttributeValues = lastCardLevelAttributeValues {
            attributeIds = Array(attributes.keys) + Array(lastCardLevelAttributeValues.keys)
        } else {
            attributeIds = Array(attributes.keys)
        }
        let propsClashed = actionProperties.keys.filter { attributeIds.contains($0) }
        if propsClashed.isEmpty {
            return nil
        } else {
            let propsListThatClashed = propsClashed.joined(separator: ", ")
            return "Error in setProps() because these props clash with attribute(s): \(propsListThatClashed)"
        }
    }

    private func handleCommandForDappAction(_ command: DappCommand) {
        //limited signing capability exposed for TokenScript for now. Be careful not to expose more than we want to
        switch command.name {
        case .signPersonalMessage:
            break
        case .signTransaction, .sendTransaction, .signMessage, .signTypedMessage, .ethCall, .unknown:
            return
        }

        //TODO clean up this. Some of these are wrong, eg: transactionType. They are only here so we can sign personal message
        let requester = DAppRequester(title: webView.title, url: webView.url)
        let token = MultipleChainsTokensDataStore.functional.token(forServer: server)
        let action = DappAction.fromCommand(.eth(command), server: server, transactionType: .dapp(token, requester))

        func _sign(action: DappAction, command: DappCommand, account: AlphaWallet.Address) {
            switch action {
            case .signPersonalMessage(let hexMessage):
                let msg = convertMessageToHex(msg: hexMessage)
                let callbackID = command.id
                signMessage(with: .personalMessage(Data(_hex: msg)), account: account, callbackID: callbackID)
            case .signTransaction, .sendTransaction, .signMessage, .signTypedMessage, .unknown, .sendRawTransaction, .signTypedMessageV3, .ethCall, .walletAddEthereumChain, .walletSwitchEthereumChain:
                break
            }
        }

        switch wallet.type {
        case .real(let account):
            _sign(action: action, command: command, account: account)
        case .watch(let account):
            //TODO pass in Config instance instead
            if Config().development.shouldPretendIsRealWallet {
                _sign(action: action, command: command, account: account)
            } else {
                //no-op
            }
        }
    }
}

//Block navigation. Still good to have even if we end up using XSLT?
extension TokenInstanceWebView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString, url == "about:blank" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}

extension TokenInstanceWebView: WKUIDelegate {
    func webViewDidClose(_ webView: WKWebView) {
        delegate?.shouldClose(tokenInstanceWebView: self)
    }
}

//TODO this contains functions duplicated and modified from DappBrowserCoordinator. Clean this up. Or move it somewhere, to a coordinator?
extension TokenInstanceWebView: Coordinator {
    
    //allow the message to be passed in as a pure string, if it is then we convert it to hex
    private func convertMessageToHex(msg: String) -> String {
        if msg.hasPrefix("0x") {
            return msg
        } else {
            return msg.hex
        }
    }

    func signMessage(with type: SignMessageType, account: AlphaWallet.Address, callbackID: Int) {
        guard let navigationController = delegate?.navigationControllerFor(tokenInstanceWebView: self) else { return }
        firstly {
            SignMessageCoordinator.promise(analytics: analytics, navigationController: navigationController, keystore: keystore, coordinator: self, signType: type, account: account, source: .tokenScript, requester: nil)
        }.done { data in
            let callback: DappCallback
            switch type {
            case .message:
                callback = DappCallback(id: callbackID, value: .signMessage(data))
            case .personalMessage:
                callback = DappCallback(id: callbackID, value: .signPersonalMessage(data))
            case .typedMessage:
                callback = DappCallback(id: callbackID, value: .signTypedMessage(data))
            case .eip712v3And4:
                callback = DappCallback(id: callbackID, value: .signTypedMessageV3(data))
            }

            self.notifyFinish(callbackID: callbackID, value: .success(callback))
        }.catch { _ in
            self.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
        }
    }
}

//TODO this contains functions duplicated and modified from BrowserViewController. Clean this up. Or move it somewhere, to a coordinator?
extension TokenInstanceWebView {
    func notifyFinish(callbackID: Int, value: Swift.Result<DappCallback, DAppError>) {
        let script: String = {
            switch value {
            case .success(let result):
                return "executeCallback(\(callbackID), null, \"\(result.value.object)\")"
            case .failure(let error):
                return "executeCallback(\(callbackID), \"\(error)\", null)"
            }
        }()
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func notifyTokenScriptFinish(callbackID: Int, errorMessage: String?) {
        let script: String = {
            if let errorMessage = errorMessage {
                return "executeTokenScriptCallback(\(callbackID), \"\(errorMessage)\")"
            } else {
                return "executeTokenScriptCallback(\(callbackID), null)"
            }
        }()
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}
