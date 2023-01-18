//
//  BlockchainsProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import PromiseKit

public protocol BlockchainsProvider {
    func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject], shouldDelayIfCached: Bool) -> Promise<[String: Any]>
}

fileprivate let globalCallSmartContract = callSmartContract

public final class BaseBlockchainsProvider: BlockchainsProvider {
    public init() {

    }

    public func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject], shouldDelayIfCached: Bool) -> Promise<[String: Any]> {
        globalCallSmartContract(server, contract, functionName, abiString, parameters, shouldDelayIfCached)
    }
}

extension BlockchainsProvider {
    public func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [], shouldDelayIfCached: Bool = false) -> Promise<[String: Any]> {
        callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters, shouldDelayIfCached: shouldDelayIfCached)
    }
}
