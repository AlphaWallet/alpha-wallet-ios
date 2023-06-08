// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAttestation
import AlphaWalletENS
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletOpenSea
import PromiseKit

public class ConfigureApp: Initializer {
    public init() {}
    public func perform() {
        ENS.isLoggingEnabled = true
        AlphaWalletOpenSea.OpenSea.isLoggingEnabled = true

        Attestation.isLoggingEnabled = true
        Attestation.callSmartContract = { chainId, contract, functionName, abiString, parameters in
            return try await withCheckedThrowingContinuation { continuation in
                firstly {
                    callSmartContract(withServer: RPCServer(chainID: chainId), contract: contract, functionName: functionName, abiString: abiString, parameters: parameters)
                }.done { result in
                    continuation.resume(returning: result)
                }.catch {
                    continuation.resume(throwing: $0)
                }
            }
        }
    }
}

public class DatabasePathLog: Initializer {
    public init() {}
    public func perform() {
        let config = RealmConfiguration.configuration(name: "")
        debugLog("Database filepath: \(config.fileURL!)")
        debugLog("Database directory: \(config.fileURL!.deletingLastPathComponent())")
    }
}
