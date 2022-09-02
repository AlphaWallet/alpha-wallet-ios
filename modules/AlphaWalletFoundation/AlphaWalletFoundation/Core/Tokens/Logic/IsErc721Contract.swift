//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import PromiseKit
import web3swift

public class IsErc721Contract {
    private let server: RPCServer

    private struct DoesNotSupportERC165Querying {
        static let bitizen = "0xb891c4d89c1bf012f0014f56ce523f248a07f714"
        static let cryptoSaga = "0xabc7e6c01237e8eef355bba2bf925a730b714d5f"
    }

    private struct ERC165Hash {
        static let official = "0x80ac58cd"
        //https://github.com/ethereum/EIPs/commit/d164cb2031503665c7dfbb759272f63c29b2b848
        static let old = "0x6466353c"
        //CryptoKitties' ERC165 interface signature for ERC721 is wrong
        //Using "kat" instead of "cryptokitties" to avoid being mistakenly detected by app review as supporting CryptoKitties
        static let onlyKat = "0x9a20483d"
    }
    private let queue: DispatchQueue

    public init(forServer server: RPCServer, queue: DispatchQueue = .global()) {
        self.server = server
        self.queue = queue
    }

    func getIsERC721Contract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        let server = self.server
        if contract.sameContract(as: DoesNotSupportERC165Querying.bitizen) {
            return .value(true)
        }
        if contract.sameContract(as: DoesNotSupportERC165Querying.cryptoSaga) {
            return .value(true)
        }

        let function = GetInterfaceSupported165Encode()

        let cryptoKittyPromise = callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [ERC165Hash.onlyKat] as [AnyObject])

        let nonCryptoKittyERC721Promise = callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [ERC165Hash.official] as [AnyObject])

        let nonCryptoKittyERC721WithOldInterfaceHashPromise = callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [ERC165Hash.old] as [AnyObject])

        //Slower than theoretically possible because we wait for every promise to be resolved. In theory we can stop when any promise is fulfilled with true. But code is much less elegant
        return firstly {
            when(resolved: cryptoKittyPromise, nonCryptoKittyERC721Promise, nonCryptoKittyERC721WithOldInterfaceHashPromise)
        }.map { _ -> Bool in
            let isCryptoKitty = cryptoKittyPromise.value?["0"] as? Bool
            let isNonCryptoKittyERC721 = nonCryptoKittyERC721Promise.value?["0"] as? Bool
            let isNonCryptoKittyERC721WithOldInterfaceHash = nonCryptoKittyERC721WithOldInterfaceHashPromise.value?["0"] as? Bool
            if let isCryptoKitty = isCryptoKitty, isCryptoKitty {
                return true
            } else if let isNonCryptoKittyERC721 = isNonCryptoKittyERC721, isNonCryptoKittyERC721 {
                return true
            } else if let isNonCryptoKittyERC721WithOldInterfaceHash = isNonCryptoKittyERC721WithOldInterfaceHash, isNonCryptoKittyERC721WithOldInterfaceHash {
                return true
            } else if isCryptoKitty != nil, isNonCryptoKittyERC721 != nil, isNonCryptoKittyERC721WithOldInterfaceHash != nil {
                return false
            } else {
                throw createSmartContractCallError(forContract: contract, functionName: function.name)
            }
        }
    }
}
