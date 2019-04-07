// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import WebKit
import JavaScriptCore
import TrustKeystore

extension WKWebViewConfiguration {

    static func make(forServer server: RPCServer, address: Address, in messageHandler: WKScriptMessageHandler) -> WKWebViewConfiguration {
        let webViewConfig = WKWebViewConfiguration()
        var js = ""

        guard
            let bundlePath = Bundle.main.path(forResource: "AlphaWalletWeb3Provider", ofType: "bundle"),
            let bundle = Bundle(path: bundlePath) else { return webViewConfig }

        if let filepath = bundle.path(forResource: "AlphaWallet-min", ofType: "js") {
            do {
                js += try String(contentsOfFile: filepath)
            } catch { }
        }

        js +=
        """
        const addressHex = "\(address.description.lowercased())"
        const rpcURL = "\(server.rpcURL.absoluteString)"
        const chainID = "\(server.chainID)"

        function executeCallback (id, error, value) {
            AlphaWallet.executeCallback(id, error, value)
        }

        AlphaWallet.init(rpcURL, {
            getAccounts: function (cb) { cb(null, [addressHex]) },
            processTransaction: function (tx, cb){
                console.log('signing a transaction', tx)
                const { id = 8888 } = tx
                AlphaWallet.addCallback(id, cb)
                webkit.messageHandlers.signTransaction.postMessage({"name": "signTransaction", "object": tx, id: id})
            },
            signMessage: function (msgParams, cb) {
                const { data } = msgParams
                const { id = 8888 } = msgParams
                console.log("signing a message", msgParams)
                AlphaWallet.addCallback(id, cb)
                webkit.messageHandlers.signMessage.postMessage({"name": "signMessage", "object": { data }, id: id})
            },
            signPersonalMessage: function (msgParams, cb) {
                const { data } = msgParams
                const { id = 8888 } = msgParams
                console.log("signing a personal message", msgParams)
                AlphaWallet.addCallback(id, cb)
                webkit.messageHandlers.signPersonalMessage.postMessage({"name": "signPersonalMessage", "object": { data }, id: id})
            },
            signTypedMessage: function (msgParams, cb) {
                const { data } = msgParams
                const { id = 8888 } = msgParams
                console.log("signing a typed message", msgParams)
                AlphaWallet.addCallback(id, cb)
                webkit.messageHandlers.signTypedMessage.postMessage({"name": "signTypedMessage", "object": { data }, id: id})
            }
        }, {
            address: addressHex,
            networkVersion: chainID
        })

        web3.setProvider = function () {
            console.debug('AlphaWallet Wallet - overrode web3.setProvider')
        }

        web3.eth.defaultAccount = addressHex

        web3.version.getNetwork = function(cb) {
            cb(null, chainID)
        }

        web3.eth.getCoinbase = function(cb) {
            return cb(null, addressHex)
        }
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webViewConfig.userContentController.add(messageHandler, name: Method.signTransaction.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signPersonalMessage.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signMessage.rawValue)
        webViewConfig.userContentController.add(messageHandler, name: Method.signTypedMessage.rawValue)
        webViewConfig.userContentController.addUserScript(userScript)
        return webViewConfig
    }
}
