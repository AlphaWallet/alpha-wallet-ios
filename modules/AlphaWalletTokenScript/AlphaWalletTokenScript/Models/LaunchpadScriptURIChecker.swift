// Copyright © 2024 Stormbird PTE. LTD.

import AlphaWalletAddress
import AlphaWalletCore

import Alamofire

fileprivate struct LaunchpadScriptURI: Decodable {
    let scriptURI: [String: [String]?]
}

public class LaunchpadScriptURIChecker {
    private var cacheHasTokenScript: [AddressAndRPCServer: Bool] = [:]

    public func hasTokenScript(contract: AlphaWallet.Address, server: RPCServer) async -> Bool {
        let key = AddressAndRPCServer(address: contract, server: server)
        if let result = cacheHasTokenScript[key] {
            return result
        }

        let url = URL(string: "https://store-backend.smartlayer.network/tokenscript/\(contract.eip55String)/chain/\(server.chainID)/script-uri")!
        return (try? await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .get).responseData { response in
                switch response.result {
                case .success(let data):
                    if let scriptURI = (try? JSONDecoder().decode(LaunchpadScriptURI.self, from: data))?.scriptURI {
                        let erc5169 = scriptURI["erc5169"]
                        let offchain = scriptURI["offchain"]
                        if !(erc5169?.isEmpty ?? true) || !(offchain?.isEmpty ?? true) {
                            self.cacheHasTokenScript[key] = true
                            continuation.resume(returning: true)
                        } else {
                            self.cacheHasTokenScript[key] = false
                            continuation.resume(returning: false)
                        }
                    } else {
                        self.cacheHasTokenScript[key] = false
                        continuation.resume(returning: false)
                    }
                case .failure(let error):
                    self.cacheHasTokenScript[key] = false
                    continuation.resume(returning: false)
                }
            }
        }) ?? false
    }

    public func prefetchHasTokenScript(contract: AlphaWallet.Address, server: RPCServer) {
        Task {
            _ = await hasTokenScript(contract: contract, server: server)
        }

    }
}
