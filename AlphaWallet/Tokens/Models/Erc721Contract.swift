// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import PromiseKit

class Erc721Contract {
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func getErc721TokenUri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        firstly {
            getErc721TokenUriImpl(for: tokenId, contract: contract)
        }.recover { _ in
            self.getErc721Uri(for: tokenId, contract: contract)
        }
    }

    private func getErc721TokenUriImpl(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        let function = GetERC721TokenUri()
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [tokenId] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout)
        }.map { uriResult -> URL in
            let string = (uriResult["0"] as? String) ?? ""
            if let url = URL(string: string) {
                return url
            } else {
                throw Web3Error(description: "Error extracting tokenUri for contract \(contract.eip55String) tokenId: \(tokenId)")
            }
        }
    }

    private func getErc721Uri(for tokenId: String, contract: AlphaWallet.Address) -> Promise<URL> {
        let function = GetERC721Uri()
        return firstly {
            callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [tokenId] as [AnyObject], timeout: TokensDataStore.fetchContractDataTimeout)
        }.map { uriResult -> URL in
            let string = (uriResult["0"] as? String) ?? ""
            if let url = URL(string: string) {
                return url
            } else {
                throw Web3Error(description: "Error extracting tokenUri uri for contract \(contract.eip55String) tokenId: \(tokenId)")
            }
        }
    }
}