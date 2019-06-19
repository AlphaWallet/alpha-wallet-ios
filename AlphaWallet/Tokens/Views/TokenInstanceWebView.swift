// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit
import TrustKeystore
import WebKit

protocol TokenInstanceWebViewDelegate: class {
    //TODO not good. But quick and dirty to ship
    func navigationControllerFor(tokenInstanceWebView: TokenInstanceWebView) -> UINavigationController?
    func shouldClose(tokenInstanceWebView: TokenInstanceWebView)
}


class TokenInstanceWebView: UIView {
    //TODO see if we can be smarter about just subscribing to the attribute once. Note that this is not `Subscribable.subscribeOnce()`
    private let server: RPCServer
    private let walletAddress: AlphaWallet.Address
    private let assetDefinitionStore: AssetDefinitionStore
    lazy private var heightConstraint = heightAnchor.constraint(equalToConstant: 100)
    lazy private var webView: WKWebView = {
        let webViewConfig = WKWebViewConfiguration.make(forType: .tokenScriptRenderer, server: server, address: walletAddress, in: ScriptMessageProxy(delegate: self))
        webViewConfig.websiteDataStore = .default()
        return .init(frame: .zero, configuration: webViewConfig)
    }()

    var isWebViewInteractionEnabled: Bool = false {
        didSet {
            webView.isUserInteractionEnabled = isWebViewInteractionEnabled
        }
    }
    weak var delegate: TokenInstanceWebViewDelegate?

    init(server: RPCServer, walletAddress: AlphaWallet.Address, assetDefinitionStore: AssetDefinitionStore) {
        self.server = server
        self.walletAddress = walletAddress
        self.assetDefinitionStore = assetDefinitionStore
        super.init(frame: .zero)

        webView.isUserInteractionEnabled = false
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ] +  [heightConstraint])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //Implementation: String concatentation is slow, but it's not obvious at all
    func update(withTokenHolder tokenHolder: TokenHolder, isFungible: Bool, isFirstUpdate: Bool = true) {
        var token = [AttributeId: String]()
        token["_count"] = String(tokenHolder.count)

        let attributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        let resolvedAttributeNameValues = attributeValues.resolve { [weak self] _ in
            guard let strongSelf = self else { return }
            guard isFirstUpdate else { return }
            strongSelf.update(withTokenHolder: tokenHolder, isFungible: isFungible, isFirstUpdate: false)
        }.merging(implicitAttributes(tokenHolder: tokenHolder, isFungible: isFungible)) { (_, new) in new }

        let convertor = AssetAttributeToJavaScriptConvertor()
        for (name, value) in resolvedAttributeNameValues {
            if let value = convertor.formatAsTokenScriptJavaScript(value: value) {
                token[name] = value
            }
        }

        var string = "\nweb3.tokens.data.currentInstance = {\n"
        for (name, value) in token {
            string += "\(name): \(value),"
        }
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

        string += """
                  \nweb3.tokens.dataChanged(oldTokens, web3.tokens.data)
                  """
        let javaScript = """
                         console.log('update() ran')
                         const oldTokens = web3.tokens.data
                         """ + string

        //Important to inject JavaScript differently depending on whether this is the first time it's loaded because the HTML document may not be ready yet
        inject(javaScript: javaScript, afterDocumentIsLoaded: isFirstUpdate)
    }

    private func implicitAttributes(tokenHolder: TokenHolder, isFungible: Bool) -> [String: AssetInternalValue] {
        var results = [String: AssetInternalValue]()
        for each in AssetImplicitAttributes.allCases {
            guard each.shouldInclude(forAddress: tokenHolder.contractAddress, isFungible: isFungible) else { continue }
            switch each {
            case .ownerAddress:
                results[each.javaScriptName] = .address(walletAddress)
            case .tokenId:
                results[each.javaScriptName] = .uint(tokenHolder.tokens[0].id)
            case .name:
                let localizedNameFromAssetDefinition = XMLHandler(contract: tokenHolder.contractAddress, assetDefinitionStore: assetDefinitionStore).getName(fallback: tokenHolder.name)
                results[each.javaScriptName] = .string(localizedNameFromAssetDefinition)
            case .symbol:
                results[each.javaScriptName] = .string(tokenHolder.symbol)
            case .contractAddress:
                //TODO remove forced unwrap once we get TokenHolder to use AlphaWallet.Address instead
                results[each.javaScriptName] = .address(tokenHolder.contractAddress)
            }
        }
        return results
    }

    @discardableResult func inject(javaScript: String, afterDocumentIsLoaded: Bool = false) -> Promise<Any?>? {
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

    func loadHtml(_ html: String) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "estimatedProgress" else { return }
        guard webView.estimatedProgress == 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.makeIntroductionWebViewFullHeight()
        }
    }

    private func makeIntroductionWebViewFullHeight() {
        heightConstraint.constant = webView.scrollView.contentSize.height
    }
}

extension TokenInstanceWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let command = DappAction.fromMessage(message) else { return }

        //limited signing capability exposed for TokenScript for now. Be careful not to expose more than we want to
        switch command.name {
        case .signPersonalMessage:
            break
        case .signTransaction, .sendTransaction, .signMessage, .signTypedMessage, .unknown:
            return
        }

        //TODO clean up this. Some of these are wrong, eg: Transfer(). They are only here so we can sign personal message
        let requester = DAppRequester(title: webView.title, url: webView.url)
        let token = TokensDataStore.token(forServer: server)
        let transfer = Transfer(server: server, type: .dapp(token, requester))
        let action = DappAction.fromCommand(command, transfer: transfer)

        //TODO pass this in instead
        let wallet = (try! EtherKeystore()).recentlyUsedWallet!

        guard case .real(let account) = wallet.type else { return }

        switch action {
        case .signPersonalMessage(let hexMessage):
            let msg = convertMessageToHex(msg: hexMessage)
            let callbackID = command.id
            signMessage(with: .personalMessage(Data(hex: msg)), account: account, callbackID: callbackID)
        case .signTransaction, .sendTransaction, .signMessage, .signTypedMessage, .unknown:
            return
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
extension TokenInstanceWebView {
    //allow the message to be passed in as a pure string, if it is then we convert it to hex
    private func convertMessageToHex(msg: String) -> String {
        if msg.hasPrefix("0x") {
            return msg
        } else {
            return msg.hex
        }
    }

    func signMessage(with type: SignMessageType, account: Account, callbackID: Int) {
        guard let navigationController = delegate?.navigationControllerFor(tokenInstanceWebView: self) else { return }

        //TODO pass in keystore
        let coordinator = SignMessageCoordinator(
                navigationController: navigationController,
                keystore: try! EtherKeystore(),
                account: account
        )
        coordinator.didComplete = { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let data):
                let callback: DappCallback
                switch type {
                case .message:
                    callback = DappCallback(id: callbackID, value: .signMessage(data))
                case .personalMessage:
                    callback = DappCallback(id: callbackID, value: .signPersonalMessage(data))
                case .typedMessage:
                    callback = DappCallback(id: callbackID, value: .signTypedMessage(data))
                }
                strongSelf.notifyFinish(callbackID: callbackID, value: .success(callback))
            case .failure:
                strongSelf.notifyFinish(callbackID: callbackID, value: .failure(DAppError.cancelled))
            }
            coordinator.didComplete = nil
        }
        coordinator.start(with: type)
    }
}

//TODO this contains functions duplicated and modified from BrowserViewController. Clean this up. Or move it somewhere, to a coordinator?
extension TokenInstanceWebView {
    func notifyFinish(callbackID: Int, value: ResultResult<DappCallback, DAppError>.t) {
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
}

func wrapWithHtmlViewport(_ html: String) -> String {
    if html.isEmpty {
        return ""
    } else {
        return """
               <html>
               <head>
               <meta name="viewport" content="width=device-width, initial-scale=1,  maximum-scale=1, shrink-to-fit=no">
               </head>
               \(html)
               </html>
               """
    }
}
