// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

final class NonFungibleContract {
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func getUriOrTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        firstly {
            self.getTokenUri(for: tokenId, contract: contract)
        }.recover { _ in
            self.getUri(for: tokenId, contract: contract)
        }
    }

    private func getTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        let function = GetTokenUri()
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [tokenId] as [AnyObject])
        }.map(on: .global(), { uriResult -> URL in
            if let string = uriResult["0"] as? String, let url = URL(string: string.stringWithTokenIdSubstituted(tokenId)) {
                return url
            } else {
                throw CastError(actualValue: uriResult["0"], expectedType: URL.self)
            }
        })
    }

    private func getUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        let function = GetUri()
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [tokenId] as [AnyObject])
        }.map(on: .global(), { uriResult -> URL in
            if let string = uriResult["0"] as? String, let url = URL(string: string.stringWithTokenIdSubstituted(tokenId)) {
                return url
            } else {
                throw CastError(actualValue: uriResult["0"], expectedType: URL.self)
            }
        })
    }
}

extension String {
    fileprivate func stringWithTokenIdSubstituted(_ tokenId: String) -> String {
        //According to https://eips.ethereum.org/EIPS/eip-1155
        //The string format of the substituted hexadecimal ID MUST be lowercase alphanumeric: [0-9a-f] with no 0x prefix.
        //The string format of the substituted hexadecimal ID MUST be leading zero padded to 64 hex characters length if necessary.
        if let tokenId = BigInt(tokenId) {
            let hex = String(tokenId, radix: 16).padding(toLength: 64, withPad: "0", startingAt: 0)
            return self.replacingOccurrences(of: "{id}", with: hex)
        } else {
            return self
        }
    }
}
