// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import UIKit
import WebKit
import AlphaWalletABI
import AlphaWalletAddress
import AlphaWalletAttestation
import AlphaWalletBrowser
import AlphaWalletCore
import AlphaWalletWeb3
import AlphaWalletLogger
import BigInt
import PromiseKit

public protocol TokenScriptWebViewDelegate: AnyObject {
    func shouldClose(tokenScriptWebView: TokenScriptWebView)
    func reinject(tokenScriptWebView: TokenScriptWebView) async
    func requestSignMessage(message: SignMessageType, server: RPCServer, account: AlphaWallet.Address, inTokenScriptWebView tokenScriptWebView: TokenScriptWebView) -> AnyPublisher<Data, PromiseError>
}

public class TokenScriptWebView: UIView, TokenScriptLocalRefsSource {
    //TODO see if we can be smarter about just subscribing to the attribute once. Note that this is not `Subscribable.subscribeOnce()`
    private let wallet: WalletType
    private let assetDefinitionStore: AssetDefinitionStore
    private lazy var heightConstraint = heightAnchor.constraint(equalToConstant: 100)
    private lazy var webView: WKWebView = {
        let webViewConfig = WKWebViewConfiguration.make(forType: .tokenScriptRenderer(serverWithInjectableRpcUrl), address: wallet.address, messageHandler: ScriptMessageProxy(delegate: self))
        webViewConfig.websiteDataStore = .default()
        let webView = WKWebView(frame: .init(x: 0, y: 0, width: 40, height: 40), configuration: webViewConfig)
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        return webView
    }()
    private let shouldPretendIsRealWallet: Bool
    private var lastInjectedJavaScript: String?
    //TODO remove once we refactor internals to include a TokenScriptContext
    private var lastTokenHolder: TokenHolderProtocol?
    private var actionProperties: SetProperties.Properties = .init()
    private var lastCardLevelAttributeValues: [AttributeId: AssetAttributeSyntaxValue]?
    private var cancelable = Set<AnyCancellable>()
    private var serverWithInjectableRpcUrl: WithInjectableRpcUrl
    private var server: RPCServer

    public var isWebViewInteractionEnabled: Bool = false {
        didSet {
            webView.isUserInteractionEnabled = isWebViewInteractionEnabled
        }
    }
    public weak var delegate: TokenScriptWebViewDelegate?
    //HACK: Flag necessary to inject token values somewhat reliably in at least 2 distinct cases:
    //A. TokenScript views in token cards (ie. view iconified)
    //B. Action views
    //TODO improve further. It's not reliable enough
    public var isStandalone = false

    public var localRefs: [AttributeId: AssetInternalValue] {
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

    public override var backgroundColor: UIColor? {
        didSet {
            webView.backgroundColor = backgroundColor
        }
    }

    //Have a serverWithInjectableRpcUrl because RPCServer only conforms to serverWithInjectableRpcUrl outside of AlphaWalletTokenScript pod
    public init(server: RPCServer, serverWithInjectableRpcUrl: WithInjectableRpcUrl, wallet: WalletType, assetDefinitionStore: AssetDefinitionStore, shouldPretendIsRealWallet: Bool = false) {
        self.server = server
        self.serverWithInjectableRpcUrl = serverWithInjectableRpcUrl
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.shouldPretendIsRealWallet = shouldPretendIsRealWallet
        super.init(frame: .zero)

        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        webView.scrollView
            .publisher(for: \.contentSize, options: [.new, .initial])
            .removeDuplicates()
            .map { $0.height }
            .assign(to: \.constant, on: heightConstraint, ownership: .weak)
            .store(in: &cancelable)

        NSLayoutConstraint.activate([
            webView.anchorsConstraint(to: self),
            heightConstraint,
        ])

        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func stopLoading() {
        webView.stopLoading()
    }
    private var cancellable: AnyCancellable?

    //The 2 args are always the same but because conformance is defined outside of this pod, we have to do this
    public func setServer(_ server: RPCServer, serverWithInjectableRpcUrl: WithInjectableRpcUrl) {
        self.server = server
        self.serverWithInjectableRpcUrl = serverWithInjectableRpcUrl
    }

    //Implementation: String concatenation is slow, but it's not obvious at all
    public func update(withTokenHolder tokenHolder: TokenHolderProtocol, cardLevelAttributeValues updatedCardLevelAttributeValues: [AttributeId: AssetAttributeSyntaxValue]? = nil, isFungible: Bool, isFirstUpdate: Bool = true) {
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

        cancellable?.cancel()
        cancellable = Publishers.CombineLatest(tokenAttributeValues.resolveAllAttributes(), cardAttributeValues.resolveAllAttributes())
            .sink { [weak self] resolvedTokenAttributeNameValues, resolvedCardAttributeNameValues in
                self?.update(withId: tokenHolder.tokenId, resolvedTokenAttributeNameValues: resolvedTokenAttributeNameValues, resolvedCardAttributeNameValues: resolvedCardAttributeNameValues, isFirstUpdate: isFirstUpdate)
            }
    }

    public func update(withId id: BigUInt, resolvedTokenAttributeNameValues: [AttributeId: AssetInternalValue], resolvedCardAttributeNameValues: [AttributeId: AssetInternalValue], attestation: Attestation? = nil, isFirstUpdate: Bool = true) {
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
        //Patching for compatibility with Android, so image_preview_url is available
        if tokenData["image_preview_url"] == nil && tokenData["imageUrl"] != nil {
            tokenData["image_preview_url"] = tokenData["imageUrl"]
        }

        let tokenDataString = tokenData.map { name, value in "\(name): \(value)," }.joined()
        let cardDataString = cardData.map { name, value in "\(name): \(value)," }.joined()
        //TODO remove this soon since it's no longer in the JavaScript API
        let combinedData = tokenData.merging(cardData, uniquingKeysWith: { _, new in new })

        var string: String
        //TODO currently only a token or attestation can be exposed, mutually exclusively
        if let attestation {
            string = "\nweb3.tokens.data.currentInstance = \n"
            string += """
                         {
                            "chainId":\(attestation.chainId),
                            "ownerAddress":"\(wallet.address.eip55String)",
                            "rawAttestation":"\(functional.fixRawAttestationFormat(rawAttestation: Attestation.extractRawAttestation(fromUrlString: attestation.source) ?? attestation.source))",
                            "attestationSig":"\(attestation.signature.hexEncoded)",
                            "attestation":"\(attestation.abiEncoded.hexEncoded)",
                            "attest":\(attestation.messageJson)
                         }
                      """
            string += "\n"
        } else {
            let combinedDataString = combinedData.map { name, value in "\(name): \(value)," }.joined()
            string = "\nweb3.tokens.data.currentInstance = {\n"
            string += combinedDataString
            string += "\n}"
        }

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

    public func updateWithAttestation(_ attestation: Attestation, withId id: BigUInt, isFirstUpdate: Bool = true) {
        update(withId: id, resolvedTokenAttributeNameValues: .init(), resolvedCardAttributeNameValues: .init(), attestation: attestation, isFirstUpdate: isFirstUpdate)
    }

    private func unresolvedAttributesDependentOnProps(tokenHolder: TokenHolderProtocol) -> [AttributeId: AssetAttributeSyntaxValue] {
        guard !localRefs.isEmpty else { return .init() }
        let xmlHandler = assetDefinitionStore.xmlHandler(forContract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType)
        let attributes = xmlHandler.fields.filter { $0.value.isDependentOnProps && lastCardLevelAttributeValues?[$0.key] == nil }

        return assetDefinitionStore
            .assetAttributeResolver
            .resolve(withTokenIdOrEvent: .tokenId(tokenId: tokenHolder.tokenId),
                     userEntryValues: .init(),
                     server: server,
                     account: wallet.address,
                     additionalValues: .init(),
                     localRefs: localRefs,
                     attributes: attributes)
    }

    private func implicitAttributes(tokenHolder: TokenHolderProtocol, isFungible: Bool) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        for each in AssetImplicitAttributes.allCases {
            guard each.shouldInclude(forAddress: tokenHolder.contractAddress, isFungible: isFungible) else { continue }
            switch each {
            case .ownerAddress:
                results[each.javaScriptName] = .address(wallet.address)
            case .tokenId:
                results[each.javaScriptName] = .uint(tokenHolder.tokenId)
            case .label:
                let localizedNameFromAssetDefinition = assetDefinitionStore.xmlHandler(forContract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType).getLabel(fallback: tokenHolder.name)
                results[each.javaScriptName] = .string(localizedNameFromAssetDefinition)
            case .symbol:
                results[each.javaScriptName] = .string(tokenHolder.symbol)
            case .contractAddress:
                results[each.javaScriptName] = .address(tokenHolder.contractAddress)
            }
        }
        return results
    }

    @discardableResult public func inject(javaScript: String, afterDocumentIsLoaded: Bool = false) -> Promise<Any?>? {
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

    public func loadHtml(_ html: String, urlFragment: String?) {
        if let urlFragment {
            loadHtmlAsBase64(html, withUrlFragment: urlFragment)
        } else {
            loadHtmlWithoutUrlFragment(html)
        }
    }

    private func loadHtmlWithoutUrlFragment(_ html: String) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func loadHtmlAsBase64(_ html: String, withUrlFragment urlFragment: String) {
        if let data = html.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            let dataUrlString = "data:text/html;base64,\(base64)#\(urlFragment)"
            let url = URL(dataRepresentation: Data(dataUrlString.utf8), relativeTo: URL(string: "about:blank")!)!
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            loadHtmlWithoutUrlFragment(html)
        }
    }

    private func sign(message: String?, command: DappCommand, account: AlphaWallet.Address) {
        guard let message else { return }

        guard let delegate = self.delegate else {
            self.notifyFinish(callbackId: command.id, value: .failure(JsonRpcError.requestRejected))
            return
        }

        delegate.requestSignMessage(message: .personalMessage(message.asSignableMessageData), server: server, account: account, inTokenScriptWebView: self)
                .handleEvents(receiveCancel: {
                    self.notifyFinish(callbackId: command.id, value: .failure(JsonRpcError.requestRejected))
                })
                .sinkAsync(receiveCompletion: { _ in
                    self.notifyFinish(callbackId: command.id, value: .failure(JsonRpcError.requestRejected))
                }, receiveValue: { value in
                    let callback = DappCallback(id: command.id, value: .signPersonalMessage(value))
                    self.notifyFinish(callbackId: command.id, value: .success(callback))
                })
    }
}

extension TokenScriptWebView: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch MessageType.fromMessage(message) {
        case .dappAction(let command):
            handleCommandForDappAction(command)
        case .setActionProps(.action(let id, let changedProperties)):
            Task {
                await handleSetActionProperties(id: id, changedProperties: changedProperties)
            }
        case .none:
            break
        }
    }

    private func handleSetActionProperties(id: Int, changedProperties: SetProperties.Properties) async {
        guard !changedProperties.isEmpty else { return }
        let oldProperties = actionProperties

        let errorMessage = checkPropsNameClashErrorWithCardAttributes()

        notifyTokenScriptFinish(callbackId: id, errorMessage: errorMessage)
        guard errorMessage == nil else { return }

        for (key, value) in changedProperties {
            actionProperties[key] = value
        }

        guard let oldJsonString = oldProperties.jsonString, let newJsonString = actionProperties.jsonString, oldJsonString != newJsonString else { return }
        if lastCardLevelAttributeValues != nil {
            await delegate?.reinject(tokenScriptWebView: self)
        }
    }

    private func checkPropsNameClashErrorWithCardAttributes() -> String? {
        guard let lastTokenHolder = lastTokenHolder else { return nil }
        let xmlHandler = assetDefinitionStore.xmlHandler(forContract: lastTokenHolder.contractAddress, tokenType: lastTokenHolder.tokenType)
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

        let message = functional.extractMessageToSign(fromCommand: command, server: server)
        switch wallet {
        case .real(let account), .hardware(let account):
            sign(message: message, command: command, account: account)
        case .watch(let account):
            if shouldPretendIsRealWallet {
                sign(message: message, command: command, account: account)
            } else {
                //no-op
            }
        }
    }
}

////Block navigation. Still good to have even if we end up using XSLT?
extension TokenScriptWebView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        //We allow loading `data:` to support urlFragments, especially useful with `<viewContent>`
        if let url = navigationAction.request.url?.absoluteString, (url == "about:blank" || navigationAction.request.url?.scheme == "data") {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}

extension TokenScriptWebView: WKUIDelegate {
    public func webViewDidClose(_ webView: WKWebView) {
        delegate?.shouldClose(tokenScriptWebView: self)
    }
}

////TODO this contains functions duplicated and modified from BrowserViewController. Clean this up. Or move it somewhere, to a coordinator?
extension TokenScriptWebView {
    private func notifyFinish(callbackId: Int, value: Swift.Result<DappCallback, JsonRpcError>) {
        let script: String = {
            switch value {
            case .success(let result):
                return "executeCallback(\(callbackId), null, \"\(result.value.object)\")"
            case .failure(let error):
                return "executeCallback(\(callbackId), \"\(error.message)\", null)"
            }
        }()
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func notifyTokenScriptFinish(callbackId: Int, errorMessage: String?) {
        let script: String = {
            if let errorMessage = errorMessage {
                return "executeTokenScriptCallback(\(callbackId), \"\(errorMessage)\")"
            } else {
                return "executeTokenScriptCallback(\(callbackId), null)"
            }
        }()
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}

fileprivate extension Attestation {
    var messageJson: String {
        let result: String
        if let messageVersion = easMessageVersion, messageVersion >= 1 {
            return """
                   {
                       "version": \(messageVersion),
                       "time": \(AttestationTypeValuePairToJavaScriptConvertor.formatAsTokenScriptJavaScriptGeneralisedTime(date: time)),
                       "data": \(TokenScriptWebView.functional.convertAttestationDataToTokenScriptJson(data)),
                       "expirationTime": \(AttestationTypeValuePairToJavaScriptConvertor.formatAsTokenScriptJavaScriptGeneralisedTime(date: expirationTime)),
                       "recipient": \(AttestationTypeValuePairToJavaScriptConvertor.formatAsTokenScriptJavaScriptAddress(address: recipient)),
                       "refUID": "\(refUID)",
                       "revocable": \(revocable),
                       "schema": "\(schemaUid.value)"
                   }
                   """
        } else {
            result = """
                     {
                         "time": \(AttestationTypeValuePairToJavaScriptConvertor.formatAsTokenScriptJavaScriptGeneralisedTime(date: time)),
                         "data": \(TokenScriptWebView.functional.convertAttestationDataToTokenScriptJson(data)),
                         "expirationTime": \(AttestationTypeValuePairToJavaScriptConvertor.formatAsTokenScriptJavaScriptGeneralisedTime(date: expirationTime)),
                         "recipient": \(AttestationTypeValuePairToJavaScriptConvertor.formatAsTokenScriptJavaScriptAddress(address: recipient)),
                         "refUID": "\(refUID)",
                         "revocable": \(revocable),
                         "schema": "\(schemaUid.value)"
                     }
                     """
        }
        return result
    }
}

extension TokenScriptWebView {
    enum functional {}
}

fileprivate extension TokenScriptWebView.functional {
    static func convertAttestationDataToTokenScriptJson(_ data: [Attestation.TypeValuePair]) -> String {
        var result = [String: String]()
        let convertor = AttestationTypeValuePairToJavaScriptConvertor()
        for each in data {
            if let value = convertor.formatAsTokenScriptJavaScript(value: each) {
                result[each.type.name] = value
            }
        }
        let resultString = result.map { name, value in "\"\(name)\": \(value)" }.joined(separator: ",")
        return "{\n\(resultString)\n}\n"
    }

    static func fixRawAttestationFormat(rawAttestation: String) -> String {
        //Important to undo/substitute this as Smart Layer API might need it
        return rawAttestation.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
    }

    static func extractMessageToSign(fromCommand command: DappCommand, server: RPCServer) -> String? {
        switch command.name {
        case .signPersonalMessage:
            let data = command.object["data"]?.value ?? ""
            return data
        case .signTransaction, .sendTransaction, .signMessage, .signTypedMessage, .ethCall, .unknown:
            warnLog("[TokenScript] Method not supported in TokenScript view: \(command.name) command: \(command)")
            return nil
        }
    }
}

////TODO remove AlphaWalletABI's dependency on TrustKeystore and then move this into Attestation (we can't do it now to avoid adding dependency to AlphaWalletAttestation on TrustKeystore)
fileprivate extension Attestation {
    var abiEncoded: Data {
        let encoder = ABIEncoder()
        do {
            try encoder.encode(tuple: [
                ABIValue.bytes(Data(hex: schemaUid.value)),
                ABIValue.address2(recipient ?? Constants.nullAddress),
                ABIValue.uint(bits: 256, BigUInt(easAttestationTime)),
                ABIValue.uint(bits: 256, BigUInt(easAttestationExpirationTime)),
                ABIValue.bool(revocable),
                ABIValue.bytes(Data(hex: refUID)),
                ABIValue.dynamicBytes(Data(hex: easAttestationData)),
            ])
            return encoder.data
        } catch {
            infoLog("[Attestation] Failed to ABI-encode attestation: \(error)")
            return Data()
        }
    }
}