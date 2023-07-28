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
        Attestation.callSmartContract = { server, contract, functionName, abiString, parameters in
            return try await callSmartContractAsync(withServer: server, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters)
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
