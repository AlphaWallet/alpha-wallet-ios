//
//  EditCustomRPCViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import Foundation

enum EditCustomRPCErrors: Error {
    case unknown
    case list([EditCustomRPCErrors]) // This is just used to hold the errors in a Result<>.
    case chainNameInvalidField, rpcEndPointInvalidField, chainIDInvalidField, symbolInvalidField, explorerEndpointInvalidField, chainIDDuplicateField
}

struct EditCustomRPCViewModel {
    
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
    
    var etherscanCompatibleType: String {
        return model.etherscanCompatibleType.rawValue
    }
    
    var isTestnet: Bool {
        return model.isTestnet
    }
    
}

extension EditCustomRPCViewModel {

    func validate(chainName: String, rpcEndpoint: String, chainID: String, symbol: String, explorerEndpoint: String, isTestNet: Bool) -> Result<CustomRPC, EditCustomRPCErrors> {
        var errors: [EditCustomRPCErrors] = []
        
        if chainName.trimmed.isEmpty {
            errors.append(.chainNameInvalidField)
        }
        
        if URL(string: rpcEndpoint.trimmed) == nil {
            errors.append(.rpcEndPointInvalidField)
        }
        
        if let chainIdInt = Int(chainId0xString: chainID.trimmed), chainIdInt > 0 {
            if validateChainIDExist(chainIdInt) {
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
    
    private func validateChainIDExist(_ chainID: Int) -> Bool {
        if chainID == self.model.chainID {
            return false
        }
        for network in RPCServer.allCases where network.chainID == chainID {
            return true
        }
        for server in RPCServer.customRpcs where server.chainID == chainID {
            return true
        }
        return false
    }
    
}
