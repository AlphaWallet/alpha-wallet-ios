//
//  SaveCustomRpcViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import Foundation

public enum SaveCustomRpcErrors: Error {
    case list([SaveCustomRpcError])
}

public enum SaveCustomRpcError: Error {
    case chainNameInvalidField, rpcEndPointInvalidField, chainIDInvalidField, symbolInvalidField, explorerEndpointInvalidField, chainIDDuplicateField
}

public struct SaveCustomRpcManualEntryViewModel {

    private let operation: SaveOperationType

    private var model: CustomRPC {
        operation.customRpc
    }

    public var chainID: String {
        if model.chainID == 0 {
            return ""
        }
        return String(model.chainID)
    }

    public var nativeCryptoTokenName: String {
        return model.nativeCryptoTokenName ?? ""
    }

    public var chainName: String {
        if model.chainName.isEmpty {
            return ""
        }
        return model.chainName
    }

    public var symbol: String {
        return model.symbol ?? ""
    }

    public var rpcEndPoint: String {
        if !model.rpcEndpoint.isEmpty,
           let _ = URL(string: model.rpcEndpoint) {
            return model.rpcEndpoint
        } else {
            return ""
        }
    }

    public var explorerEndpoint: String {
        if let eep = model.explorerEndpoint,
           !eep.isEmpty,
           let _ = URL(string: eep) {
            return eep
        } else {
            return ""
        }
    }

    public var isTestnet: Bool {
        return model.isTestnet
    }

    public var isAddOperation: Bool {
        switch operation {
        case .add:
            return true
        case .edit:
            return false
        }
    }

    public init(operation: SaveOperationType) {
        self.operation = operation
    }

}

extension SaveCustomRpcManualEntryViewModel {

    public func validate(chainName: String, rpcEndpoint: String, chainID: String, symbol: String, explorerEndpoint: String, isTestNet: Bool) -> Result<CustomRPC, SaveCustomRpcErrors> {
        var errors: [SaveCustomRpcError] = []

        if chainName.trimmed.isEmpty {
            errors.append(.chainNameInvalidField)
        }

        if URL(string: rpcEndpoint.trimmed) == nil {
            errors.append(.rpcEndPointInvalidField)
        }

        if let chainIdInt = Int(chainId0xString: chainID.trimmed), chainIdInt > 0 {
            if validateOtherChainIdExist(chainIdInt) {
                errors.append(.chainIDDuplicateField)
            }
        } else {
            errors.append(.chainIDInvalidField)
        }

        if symbol.trimmed.isEmpty {
            errors.append(.symbolInvalidField)
        }

        if URL(string: explorerEndpoint.trimmed) == nil {
            errors.append(.explorerEndpointInvalidField)
        }

        if !errors.isEmpty {
            return .failure(.list(errors))
        }

        return .success(CustomRPC(
            chainID: Int(chainId0xString: chainID.trimmed)!,
            nativeCryptoTokenName: nil,
            chainName: chainName.trimmed,
            symbol: symbol.trimmed,
            rpcEndpoint: rpcEndpoint.trimmed,
            explorerEndpoint: explorerEndpoint.trimmed,
            etherscanCompatibleType: .unknown,
            isTestnet: isTestNet)
        )
    }

    private func validateOtherChainIdExist(_ chainId: Int) -> Bool {
        if chainId == self.model.chainID {
            return false
        }

        return RPCServer.availableServers.contains { server in
            switch server {
            case .custom(let customRpc):
                return customRpc.chainID == chainId
            default:
                return server.chainID == chainId
            }
        }
    }

}
