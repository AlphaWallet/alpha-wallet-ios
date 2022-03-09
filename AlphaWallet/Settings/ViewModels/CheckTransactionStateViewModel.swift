//
//  CheckTransactionStateViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.03.2022.
//

import Foundation
import PromiseKit
import web3swift

extension TransactionState {
    init(status: TransactionReceipt.TXStatus) {
        switch status {
        case .ok:
            self = .completed
        case .failed:
            self = .failed
        case .notYetProcessed:
            self = .pending
        }
    }
}

struct CheckTransactionStateViewModel {
    private let serverSelection: ServerSelection
    private let configuration = TransactionConfirmationHeaderView.Configuration(section: 0)

    let textFieldPlaceholder: String = R.string.localizable.checkTransactionStateFieldHashPlaceholder()

    var serverSelectionViewModel: TransactionConfirmationHeaderViewModel {
        return .init(title: .normal(selectedServerString), headerName: serverViewTitle, configuration: configuration)
    }

    let title: String = R.string.localizable.checkTransactionStateTitle()
    var actionButtonTitle: String { return R.string.localizable.checkTransactionStateActionButtonTitle()}
    var serverViewTitle: String { return R.string.localizable.checkTransactionStateFieldServerTitle() }

    var selectedServerString: String {
        switch serverSelection {
        case .server(let serverOrAuto):
            switch serverOrAuto {
            case .server(let server):
                return server.name
            case .auto:
                return ""
            }
        case .multipleServers:
            return ""
        }
    }

    init(serverSelection: ServerSelection) {
        self.serverSelection = serverSelection
    }

}
