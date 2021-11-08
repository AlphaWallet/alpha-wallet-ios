//
//  EditCustomRPCViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import Foundation

enum EditCustomRPCErrors: Error {
    case unknown
    case list([EditCustomRPCErrors])
    case chainNameInvalidField, rpcEndPointInvalidField, chainIDInvalidField, symbolInvalidField, explorerEndpointInvalidField, chainIDDuplicateField
}

struct EditCustomRPCViewModel {
    
    private let customRPC: CustomRPC
    
    init(customRPC: CustomRPC) {
        self.customRPC = customRPC
    }
    
    var chainID: String {
        // TODO: Is there a validation routine for ids?
        if customRPC.chainID == 0 {
            return R.string.localizable.chainID()
        }
        return String(customRPC.chainID)
    }
    
    var nativeCryptoTokenName: String {
        return customRPC.nativeCryptoTokenName ?? ""
    }
    
    var chainName: String {
        if customRPC.chainName.isEmpty {
            return R.string.localizable.addrpcServerNetworkNameTitle()
        }
        return customRPC.chainName
    }
    
    var symbol: String {
        return customRPC.symbol ?? R.string.localizable.symbol()
    }
    
    var rpcEndPoint: String {
        if !customRPC.rpcEndpoint.isEmpty,
           let _ = URL(string: customRPC.rpcEndpoint) {
            return customRPC.rpcEndpoint
        } else {
            return R.string.localizable.addrpcServerRpcUrlTitle()
        }
    }
    
    var explorerEndpoint: String {
        if let eep = customRPC.explorerEndpoint,
           !eep.isEmpty,
           let _ = URL(string: eep) {
            return eep
        } else {
            return R.string.localizable.addrpcServerBlockExplorerUrlTitle()
        }
    }
    
    var etherscanCompatibleType: String {
        return customRPC.etherscanCompatibleType.rawValue
    }
    
    var isTestnet: Bool {
        return customRPC.isTestnet
    }
    
    // TODO: Validation
    func validate(chainName: String, rpcEndpoint: String, chainID: String, symbol: String, explorerEndpoint: String, isTestNet: Bool) -> Result<CustomRPC, EditCustomRPCErrors> {
        var errors: [EditCustomRPCErrors] = []
        
        if chainName.trimmed.isEmpty {
            errors.append(.chainNameInvalidField)
        }
        
        if URL(string: rpcEndpoint.trimmed) == nil {
            errors.append(.rpcEndPointInvalidField)
        }
        
        if let chainIdInt = Int(chainId0xString: chainID.trimmed), chainIdInt > 0 {
            if validateChainIDExists(chainID: chainIdInt) {
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
    
    private func validateChainIDExists(chainID: Int) -> Bool {
        if chainID == self.customRPC.chainID {
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
