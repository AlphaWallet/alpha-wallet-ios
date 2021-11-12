//
//  EditCustomRpcViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import Foundation

enum EditCustomRpcErrors: Error {
    case list([EditCustomRpcError])
}
enum EditCustomRpcError: Error {
    case chainNameInvalidField, rpcEndPointInvalidField, chainIDInvalidField, symbolInvalidField, explorerEndpointInvalidField, chainIDDuplicateField
}

struct EditCustomRpcViewModel {

    private let model: CustomRPC

    init(model: CustomRPC) {
        self.model = model
    }

    var chainID: String {
        if model.chainID == 0 {
            return R.string.localizable.chainID()
        }
        return String(model.chainID)
    }

    var nativeCryptoTokenName: String {
        return model.nativeCryptoTokenName ?? ""
    }

    var chainName: String {
        if model.chainName.isEmpty {
            return R.string.localizable.addrpcServerNetworkNameTitle()
        }
        return model.chainName
    }

    var symbol: String {
        return model.symbol ?? R.string.localizable.symbol()
    }

    var rpcEndPoint: String {
        if !model.rpcEndpoint.isEmpty,
           let _ = URL(string: model.rpcEndpoint) {
            return model.rpcEndpoint
        } else {
            return R.string.localizable.addrpcServerRpcUrlTitle()
        }
    }

    var explorerEndpoint: String {
        if let eep = model.explorerEndpoint,
           !eep.isEmpty,
           let _ = URL(string: eep) {
            return eep
        } else {
            return R.string.localizable.addrpcServerBlockExplorerUrlTitle()
        }
    }

    var isTestnet: Bool {
        return model.isTestnet
    }

}

extension EditCustomRpcViewModel {

    func validate(chainName: String, rpcEndpoint: String, chainID: String, symbol: String, explorerEndpoint: String, isTestNet: Bool) -> Result<CustomRPC, EditCustomRpcErrors> {
        var errors: [EditCustomRpcError] = []

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
