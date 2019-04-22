// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import TrustKeystore

struct TokenViewControllerViewModel {
    private let transferType: TransferType
    private let session: WalletSession
    private let tokensStore: TokensDataStore
    private let transactionsStore: TransactionsStorage
    let recentTransactions: [Transaction]

    init(transferType: TransferType, session: WalletSession, tokensStore: TokensDataStore, transactionsStore: TransactionsStorage) {
        self.transferType = transferType
        self.session = session
        self.tokensStore = tokensStore
        self.transactionsStore = transactionsStore

        switch transferType {
        case .nativeCryptocurrency:
            self.recentTransactions = Array(transactionsStore.objects.lazy
                    .filter({ $0.state == .completed || $0.state == .pending })
                    .filter({ $0.operation == nil })
                    .filter({ $0.value != "" && $0.value != "0" })
                    .prefix(3))
        case .ERC20Token(let token, _, _):
            self.recentTransactions = Array(transactionsStore.objects.lazy
                    .filter({ $0.state == .completed || $0.state == .pending })
                    .filter({
                        if let operation = $0.operation {
                            return operation.operationType == .erc20TokenTransfer
                        } else {
                            return false
                        }})
                    .filter({ $0.operation?.contract?.sameContract(as: token.contract) ?? false })
                    .prefix(3))
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .dapp:
            self.recentTransactions = []
        }
    }

    var destinationAddress: Address {
        return transferType.contract()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var showAlternativeAmount: Bool {
        guard let currentTokenInfo = tokensStore.tickers?[destinationAddress.description], let price = Double(currentTokenInfo.price_usd), price > 0 else {
            return false
        }
        return true
    }

    var sendButtonTitle: String {
        return R.string.localizable.send()
    }

    var receiveButtonTitle: String {
        return R.string.localizable.receive()
    }
}
