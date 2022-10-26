//
// Created by James Sangalli on 20/11/19.
//

import Foundation
import PromiseKit
import AlphaWalletCore

public class IsInterfaceSupported165 {
    private let server: RPCServer
    private let fileName: String
    private let queue = DispatchQueue(label: "org.alphawallet.swift.isInterfaceSupported165")
    private lazy var storage: Storage<[String: Bool]> = .init(fileName: fileName, storage: FileStorage(fileExtension: "json"), defaultValue: [:])
    private var inFlightPromises: [String: Promise<Bool>] = [:]

    public init(forServer server: RPCServer, fileName: String = "isInterfaceSupported165") {
        self.server = server
        self.fileName = fileName
    }

    public func getInterfaceSupported165(hash: String, contract: AlphaWallet.Address) -> Promise<Bool> {
        return firstly {
            .value(hash)
        }.then(on: queue, { [weak self, queue, server, storage] hash -> Promise<Bool> in
            let key = "\(hash)-\(contract)-\(server)"

            if let value = storage.value[key] {
                return .value(value)
            }

            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let function = GetInterfaceSupported165Encode()
                let promise = firstly {
                    callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [hash] as [AnyObject])
                }.map(on: queue, { result -> Bool in
                    guard let supported = result["0"] as? Bool else { throw CastError(actualValue: result["0"], expectedType: Bool.self) }
                    storage.value[key] = supported

                    return supported
                }).ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
    }
}
