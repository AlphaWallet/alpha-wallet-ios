//
//  AddMultipleCustomRpcViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 4/1/22.
//

import Foundation

struct AddMultipleCustomRpcViewModel {

    private let totalCustomRpc: Int

    let model: AddMultipleCustomRpcModel

    var progressString: String {
        "\(model.addedCustomRpc.count + model.failedCustomRpc.count + model.duplicateCustomRpc.count)/\(totalCustomRpc)"
    }
    var progress: Float {
        Float((model.addedCustomRpc.count + model.failedCustomRpc.count + model.duplicateCustomRpc.count)/totalCustomRpc)
    }
    var hasError: Bool {
        if model.failedCustomRpc.isEmpty, model.duplicateCustomRpc.isEmpty, model.remainingCustomRpc.isEmpty {
            return false
        }
        return true
    }

    init(model: AddMultipleCustomRpcModel) {
        self.model = model
        self.totalCustomRpc = model.remainingCustomRpc.count
    }

}
