//
// Created by James Sangalli on 20/11/19.
//

import Foundation
import PromiseKit
import AlphaWalletCore

public class IsInterfaceSupported165 {
    private let fileName: String
    private let queue = DispatchQueue(label: "org.alphawallet.swift.isInterfaceSupported165")
    private lazy var storage: Storage<[String: Bool]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])
    private var inFlightPromises: [String: Promise<Bool>] = [:]

    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider, fileName: String = "isInterfaceSupported165") {
        self.blockchainProvider = blockchainProvider
        self.fileName = fileName
    }

    public func getInterfaceSupported165(hash: String, contract: AlphaWallet.Address) -> Promise<Bool> {
        return firstly {
            .value(hash)
        }.then(on: queue, { [weak self, queue, blockchainProvider, storage] hash -> Promise<Bool> in
            let key = "\(hash)-\(contract)-\(blockchainProvider.server)"

            if let value = storage.value[key] {
                return .value(value)
            }

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let promise = blockchainProvider
                    .callPromise(Erc20SupportsInterfaceRequest(contract: contract, hash: hash))
                    .get(on: queue, { supported in
                        storage.value[key] = supported
                    }).ensure(on: queue, {
                        self?.inFlightPromises[key] = .none
                    }).get {
                        print("xxx.Erc20 supportsInterface value: \($0)")
                    }.recover { e -> Promise<Bool> in
                        print("xxx.Erc2p supportsInterface failure: \(e)")
                        throw e
                    }.ensure(on: queue, {
                        self?.inFlightPromises[key] = .none
                    })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}

struct Erc20SupportsInterfaceRequest: ContractMethodCall {
    typealias Response = Bool

    private let function = GetInterfaceSupported165Encode()
    private let hash: String

    let contract: AlphaWallet.Address
    var name: String { function.name }
    var abi: String { function.abi }
    var parameters: [AnyObject] { [hash] as [AnyObject] }

    init(contract: AlphaWallet.Address, hash: String) {
        self.contract = contract
        self.hash = hash
    }

    func response(from resultObject: Any) throws -> Bool {
        guard let dictionary = resultObject as? [String: AnyObject] else {
            throw CastError(actualValue: resultObject, expectedType: [String: AnyObject].self)
        }

        guard let supported = dictionary["0"] as? Bool else {
            throw CastError(actualValue: dictionary["0"], expectedType: Bool.self)
        }

        return supported
    }
}
