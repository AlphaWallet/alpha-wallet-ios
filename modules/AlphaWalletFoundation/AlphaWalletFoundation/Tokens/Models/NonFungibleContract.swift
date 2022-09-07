// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit

public class NonFungibleContract {
    private let server: RPCServer
    private let queue: DispatchQueue

    public init(server: RPCServer, queue: DispatchQueue) {
        self.server = server
        self.queue = queue
    }

    public func getTokenUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        firstly {
            getTokenUriImpl(for: tokenId, contract: contract)
        }.recover { _ in
            self.getUri(for: tokenId, contract: contract)
        }
    }

    private func getTokenUriImpl(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        let function = GetTokenUri()
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [tokenId] as [AnyObject], queue: queue)
        }.map(on: queue, { uriResult -> URL in
            let string = ((uriResult["0"] as? String) ?? "").stringWithTokenIdSubstituted(tokenId)
            if let url = URL(string: string) {
                return url
            } else {
                throw Web3Error(description: "Error extracting tokenUri uri for contract \(contract.eip55String) tokenId: \(tokenId) string: \(uriResult)")
            }
        })
    }

    private func getUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        let function = GetUri()
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [tokenId] as [AnyObject], queue: queue)
        }.map(on: queue, { uriResult -> URL in
            let string = ((uriResult["0"] as? String) ?? "").stringWithTokenIdSubstituted(tokenId)
            if let url = URL(string: string) {
                return url
            } else {
                throw Web3Error(description: "Error extracting token uri for contract \(contract.eip55String) tokenId: \(tokenId) string: \(uriResult)")
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
