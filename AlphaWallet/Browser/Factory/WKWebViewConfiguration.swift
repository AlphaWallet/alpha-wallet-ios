// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import WebKit
import JavaScriptCore

enum WebViewType {
    case dappBrowser
    case tokenScriptRenderer
}

extension WKWebViewConfiguration {

    static func make(forType type: WebViewType, server server: RPCServer, address: AlphaWallet.Address, in messageHandler: WKScriptMessageHandler) -> WKWebViewConfiguration {
        let webViewConfig = WKWebViewConfiguration()
        switch type {
        case .dappBrowser:
            //TODO add privacy mode switch
            let config = WKUserScriptConfig(
                address: address.eip55String,
                chainId: server.chainID,
                rpcUrl: server.rpcURL.absoluteString,
                privacyMode: false
            )
            webViewConfig.userContentController.addUserScript(config.providerScript)
            webViewConfig.userContentController.addUserScript(config.injectedScript)
            break
        case .tokenScriptRenderer:
            let script = javaScriptForTokenScriptRenderer(server: server, address: address)
            webViewConfig.userContentController.addUserScript(script)
            break
        }

        switch type {
        case .dappBrowser:
            break
        case .tokenScriptRenderer:
            //TODO enable content blocking rules to support whitelisting
//            let json = contentBlockingRulesJson()
//            if #available(iOS 11.0, *) {
//                WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "ContentBlockingRules", encodedContentRuleList: json) { (contentRuleList, error) in
//                    guard let contentRuleList = contentRuleList,
//                          error == nil else {
//                        return
//                    }
//                    webViewConfig.userContentController.add(contentRuleList)
//                }
//            }
            if #available(iOS 11.0, *) {
                webViewConfig.setURLSchemeHandler(webViewConfig, forURLScheme: "tokenscript-resource")
            }
        }

        webViewConfig.userContentController.add(messageHandler, name: Method.signTransaction.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signPersonalMessage.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signMessage.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signTypedMessage.rawValue)
        return webViewConfig
    }

    fileprivate static func javaScriptForTokenScriptRenderer(server server: RPCServer, address: AlphaWallet.Address) -> WKUserScript {
        let js = """
               window.web3CallBacks = {}

               function executeCallback (id, error, value) {
                   window.web3CallBacks[id](error, value)
                   delete window.web3CallBacks[id]
               }

               web3 = {
                 personal: {
                   sign: function (msgParams, cb) {
                     const { data } = msgParams
                     const { id = 8888 } = msgParams
                     window.web3CallBacks[id] = cb
                     webkit.messageHandlers.signPersonalMessage.postMessage({"name": "signPersonalMessage", "object":  { data }, id: id})
                   }
                 }
               }

                \n
                  web3.tokens = {
                      data: {
                          currentInstance: {
                          },
                      },
                      dataChanged: (tokens) => {
                        console.log(\"web3.tokens.data changed. You should assign a function to `web3.tokens.dataChanged` to monitor for changes like this:\\n    `web3.tokens.dataChanged = (oldTokens, updatedTokens) => { //do something }`\")
                      }
                  }

               """
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    fileprivate static func contentBlockingRulesJson() -> String {
        //TODO read from TokenScript, when it's designed and available
        let whiteListedUrls = [
            "https://unpkg.com/",
            "^tokenscript-resource://",
            "^http://stormbird.duckdns.org:8080/api/getChallenge$",
            "^http://stormbird.duckdns.org:8080/api/checkSignature"
        ]
        //Blocks everything, except the whitelisted URL patterns
        var json = """
                   [
                       {
                           "trigger": {
                               "url-filter": ".*"
                           },
                           "action": {
                               "type": "block"
                           }
                       }
                   """
        for each in whiteListedUrls {
            json += """
                    ,
                    {
                        "trigger": {
                            "url-filter": "\(each)"
                        },
                        "action": {
                            "type": "ignore-previous-rules"
                        }
                    }
                    """
        }
        json += "]"
        return json
    }
}

@available(iOS 11.0, *)
extension WKWebViewConfiguration: WKURLSchemeHandler {
    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let path = urlSchemeTask.request.url?.path {
            if let fileExtension = urlSchemeTask.request.url?.pathExtension, fileExtension == "otf", let nameWithoutExtension = urlSchemeTask.request.url?.deletingPathExtension().lastPathComponent {
                //TODO maybe good to fail with didFailWithError(error:)
                guard let url = Bundle.main.url(forResource: nameWithoutExtension, withExtension: fileExtension) else { return }
                guard let data = try? Data(contentsOf: url) else { return }
                //mimeType doesn't matter. Blocking is done based on how browser intends to use it
                let response = URLResponse(url: urlSchemeTask.request.url!, mimeType: "font/opentype", expectedContentLength: data.count, textEncodingName: nil)
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
                return
            }
        }
        //TODO maybe good to fail:
        //urlSchemeTask.didFailWithError(error:)
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        //Do nothing
    }
}


