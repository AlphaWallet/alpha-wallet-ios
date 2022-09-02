//
//  AddMultipleCustomRpcModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 4/1/22.
//

import Foundation
import AlphaWalletFoundation

class AddMultipleCustomRpcModel: NSObject {

    var addedCustomRpc: [CustomRPC] = []
    var failedCustomRpc: [CustomRPC] = []
    var duplicateCustomRpc: [CustomRPC] = []
    var remainingCustomRpc: [CustomRPC]

    init(remainingCustomRpc: [CustomRPC]) {
        self.remainingCustomRpc = remainingCustomRpc
        super.init()
    }
    
}
