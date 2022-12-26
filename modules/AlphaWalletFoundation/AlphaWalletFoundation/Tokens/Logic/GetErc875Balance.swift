// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletCore

public class GetErc875Balance {
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getErc875Balance")
    private var inFlightPromises: [String: Promise<[String]>] = [:]
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func getErc875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> Promise<[String]> {
        firstly {
            .value(contract)
        }.then(on: queue, { [weak self, queue, blockchainProvider] contract -> Promise<[String]> in
            let key = "\(address.eip55String)-\(contract.eip55String)"
            
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = blockchainProvider
                    .callPromise(Erc876BalanceOfRequest(contract: contract, address: address))
                    .get {
                        print("xxx.Erc876 balanceOf value: \($0)")
                    }.recover { e -> Promise<[String]> in
                        print("xxx.Erc876 balanceOf failure: \(e)")
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
        guard let array = values as? [Data] else { return [] }
        return array.map { each in
            let value = each.toHexString()
            return "0x\(value)"
        }
    }
}

struct Erc876BalanceOfRequest: ContractMethodCall {
    typealias Response = [String]

    private let function = GetERC875Balance()
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
        return GetErc875Balance.adapt(dictionary)
    }
}
