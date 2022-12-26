// Copyright © 2019 Stormbird PTE. LTD.

import Foundation 
import BigInt
import PromiseKit
import AlphaWalletCore

class GetErc721ForTicketsBalance {
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getErc721ForTicketsBalance")
    private var inFlightPromises: [String: Promise<[String]>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getERC721ForTicketsTokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, blockchainProvider] contract -> Promise<[String]> in
            let key = "\(address.eip55String)-\(contract.eip55String)"
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = blockchainProvider
                    .callPromise(Erc721GetBalancesRequest(contract: contract, address: address))
                    .get {
                        print("xxx.Erc721 getbalances value: \($0)")
                    }.recover { e -> Promise<[String]> in
                        print("xxx.Erc721 getbalances failure: \(e)")
                        throw e
                    }.ensure(on: queue, {
                        self?.inFlightPromises[key] = .none
                    })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }

    static func adapt(_ values: Any?) -> [String] {
        guard let array = values as? [BigUInt] else { return [] }
        return array.filter({ $0 != BigUInt(0) }).map { each in
            let value = each.serialize().hex()
            return "0x\(value)"
        }
    }
}

struct Erc721GetBalancesRequest: ContractMethodCall {
    typealias Response = [String]

    private let function = GetERC721ForTicketsBalance()
    private let address: AlphaWallet.Address

    let contract: AlphaWallet.Address
    var name: String { function.name }
    var abi: String { function.abi }
    var parameters: [AnyObject] { [address.eip55String] as [AnyObject] }

    init(contract: AlphaWallet.Address, address: AlphaWallet.Address) {
        self.address = address
        self.contract = contract
    }

    func response(from resultObject: Any) throws -> [String] {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }
        
        return GetErc721ForTicketsBalance.adapt(dictionary["0"])
    }
}
