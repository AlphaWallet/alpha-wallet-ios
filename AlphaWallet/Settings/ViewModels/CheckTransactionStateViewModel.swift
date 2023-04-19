//
//  CheckTransactionStateViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.03.2022.
//

import Foundation
import AlphaWalletFoundation
import AlphaWalletWeb3

struct CheckTransactionStateViewModel {
    private let serverSelection: ServerSelection
    private let viewState = TransactionConfirmationHeaderViewModel.ViewState(section: 0)

    let textFieldPlaceholder: String = R.string.localizable.checkTransactionStateFieldHashPlaceholder()

    var serverSelectionViewModel: TransactionConfirmationHeaderViewModel {
        return .init(title: .normal(selectedServerString), headerName: serverViewTitle, viewState: viewState)
    }

    let title: String = R.string.localizable.checkTransactionStateTitle()
    var actionButtonTitle: String { return R.string.localizable.checkTransactionStateActionButtonTitle() }
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

extension TransactionState {
    var description: String {
        switch self {
        case .completed: return R.string.localizable.transactionStateCompleted()
        case .pending: return R.string.localizable.transactionStatePending()
        case .error: return R.string.localizable.transactionStateError()
        case .failed: return R.string.localizable.transactionStateFailed()
        case .unknown: return R.string.localizable.transactionStateUnknown()
        }
    }
}

extension AlphaWalletWeb3.Web3Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionError: return "Connection Error"
        case .inputError(let e): return e
        case .nodeError(let e): return e
        case .generalError(let e): return e.localizedDescription
        case .rateLimited: return "Rate limited"
        case .responseError(let e): return e.localizedDescription
        }
    }
}
