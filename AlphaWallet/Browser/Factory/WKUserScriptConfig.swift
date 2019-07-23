//
//  Created by hewigovens on 12/1/18.
//  Copyright © 2018 hewigovens. All rights reserved.
//

import Foundation
import WebKit

struct WKUserScriptConfig {

    let address: String
    let chainId: Int
    let rpcUrl: String
    let privacyMode: Bool

    var providerJsBundleUrl: URL {
        let bundlePath = Bundle.main.path(forResource: "AlphaWalletWeb3Provider", ofType: "bundle")
        let bundle = Bundle(path: bundlePath!)!
        return bundle.url(forResource: "AlphaWallet-min", withExtension: "js")!
    }

    var providerScript: WKUserScript {
        let source = try! String(contentsOf: providerJsBundleUrl)
        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        return script
    }

    var injectedScript: WKUserScript {
        let source: String
        if privacyMode {
            source = """
                     //Space needed here because the first line is truncated
                     (function() {
                         var config = {
                             chainId: \(chainId),
                             rpcUrl: "\(rpcUrl)"
                         };
                         const provider = new window.AlphaWallet(config);
                         window.ethereum = provider;

                         window.chrome = {webstore: {}};
                     })();
                     """
        } else {
            source = """
                     //Space needed here because the first line is truncated
                     (function() {
                         var config = {
                             address: "\(address)".toLowerCase(),
                             chainId: \(chainId),
                             rpcUrl: "\(rpcUrl)"
                         };
                         const provider = new window.AlphaWallet(config);
                         window.ethereum = provider;
                         window.web3 = new window.Web3(provider);
                         window.web3.eth.defaultAccount = config.address;
                         window.chrome = {webstore: {}};
                     })();
                     """
        }
        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        return script
    }

}
