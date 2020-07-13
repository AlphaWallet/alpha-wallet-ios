// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct ConfirmPaymentDetailsViewModel {
    private let session: WalletSession
    private let transaction: PreviewTransaction
    private let currentBalance: BalanceProtocol?
    private let currencyRate: CurrencyRate?
    private let server: RPCServer
    private let fullFormatter = EtherNumberFormatter.full
    private let account: EthereumAccount
    private let ensName: String?
    private var gasViewModel: GasViewModel {
        return GasViewModel(fee: totalFee, symbol: server.symbol, currencyRate: currencyRate, formatter: fullFormatter)
    }

    private var totalFee: BigInt {
        return transaction.gasPrice * transaction.gasLimit
    }

    private var gasLimit: BigInt {
        return transaction.gasLimit
    }

    func addressReplacedWithESN(_ ensName: String? = nil) -> String {
        return account.address.addressReplacedWithESN(ensName)
    }

    var navigationTitle: String {
        return "Confirm Transaction"
    }

    init(
        transaction: PreviewTransaction,
        server: RPCServer,
        currentBalance: BalanceProtocol?,
        currencyRate: CurrencyRate?,
        session: WalletSession,
        account: EthereumAccount,
        ensName: String?
    ) {
        self.account = account
        self.session = session
        self.transaction = transaction
        self.currentBalance = currentBalance
        self.server = server
        self.currencyRate = currencyRate
        self.ensName = ensName
    }

    var amount: String {
        return fullFormatter.string(from: transaction.value)
    }

    var paymentFromTitle: String {
        return R.string.localizable.confirmPaymentFromLabelTitle()
    }

    var paymentToTitle: String {
        return R.string.localizable.confirmPaymentToLabelTitle()
    }
    var paymentToText: String {
        return transaction.address?.description ?? "--"
    }

    var gasPriceTitle: String {
        return R.string.localizable.confirmPaymentGasPriceLabelTitle()
    }

    private var gasPriceText: String {
        let unit = UnitConfiguration.gasPriceUnit
        let amount = fullFormatter.string(from: transaction.gasPrice, units: UnitConfiguration.gasPriceUnit)

        return String(format: "%@ %@", amount, unit.name)
    }

    var feeTitle: String {
        return R.string.localizable.confirmPaymentGasFeeLabelTitle()
    }

    private var feeText: String {
        let feeAndSymbol = gasViewModel.feeText
        let warningFee = BigInt(EthereumUnit.ether.rawValue) / BigInt(20)
        guard totalFee <= warningFee else {
            return R.string.localizable.confirmPaymentHighFeeWarning(feeAndSymbol)
        }
        return feeAndSymbol
    }

    var gasLimitTitle: String {
        return R.string.localizable.confirmPaymentGasLimitLabelTitle()
    }

//    var gasLimitText: String {
//        return gasLimit.description
//    }

    var amountTextColor: UIColor {
        return Colors.red
    }

    var dataTitle: String {
        return R.string.localizable.confirmPaymentDataLabelTitle()
    }

//    var dataText: String {
//        return transaction.data.description
//    }

    var nonceTitle: String {
        return R.string.localizable.confirmPaymentNonceLabelTitle()
    }

//    var nonceText: String {
//        transaction.nonce.description
//    }

    var isNonceSet: Bool {
        transaction.nonce > -1
    }

    private var hasENSName: Bool {
        return ensName != nil
    }

    var amountAttributedString: NSAttributedString {
        switch transaction.transferType {
        case .ERC20Token(let token, _, _):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .nativeCryptocurrency, .dapp:
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value)
            )
        case .ERC875Token(let token):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC875TokenOrder(let token):
            return amountAttributedText(
                    string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC721Token(let token):
            return amountAttributedText(
                string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        case .ERC721ForTicketToken(let token):
            return amountAttributedText(
                    string: fullFormatter.string(from: transaction.value, decimals: token.decimals)
            )
        }
    }

    private func amountAttributedText(string: String) -> NSAttributedString {
        let amount = NSAttributedString(
            string: amountWithSign(for: string),
            attributes: [
                .font: Fonts.regular(size: 28) as Any,
                .foregroundColor: amountTextColor,
            ]
        )

        let currency = NSAttributedString(
            string: " \(transaction.transferType.symbol)",
            attributes: [
                .font: Fonts.regular(size: 20) as Any,
            ]
        )

        return amount + currency
    }

    private func amountWithSign(for amount: String) -> String {
        guard amount != "0" else { return amount }
        return "-\(amount)"
    }

    func title(indexPath: IndexPath) -> ConfirmTransactionTableViewCellViewModel {
        switch sections[indexPath.section] {
        case .balance:
            switch balanceSectionRows[indexPath.row] {
            case .address:
                return .init(title: paymentFromTitle, subTitle: session.account.address.eip55String)
            }
        case .gas:
            switch gasSectionRows[indexPath.row] {
            case .gasLimit:
                return .init(title: gasLimitTitle, subTitle: gasLimit.description)
            case .gasPrice:
                return .init(title: gasPriceTitle, subTitle: gasPriceText)
            case .fee:
                return .init(title: feeTitle, subTitle: feeText)
            case .data:
                return .init(title: dataTitle, subTitle: transaction.data.description)
            case .nonce:
                return .init(title: nonceTitle, subTitle: transaction.nonce.description)
            }
        case .recipient:
            switch recipientSectionRows[indexPath.row] {
            case .recipient:
                return .init(title: "Wallet Address", subTitle: transaction.address?.description ?? "--")
            case .ens:
                return .init(title: "Blockie & ENS", subTitle: transaction.address?.addressReplacedWithESN(ensName))
            }
        case .amount:
            return .init(title: "", subTitle: "")
        }
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var sendButtonText: String {
        return R.string.localizable.send()
    }

    var backgroundColor: UIColor {
        return R.color.white()!
    }

    var sections: [ConfirmPaymentSection] = ConfirmPaymentSection.allCases
    var openedSections = Set<Int>()

    func numberOfRows(in section: Int) -> Int {
        let isOpened = openedSections.contains(section)

        switch sections[section] {
        case .balance:
            return isOpened ? balanceSectionRows.count : 0
        case .gas:
            return isOpened ? gasSectionRows.count : 0
        case .recipient:
            return isOpened ? recipientSectionRows.count : 0
        case .amount:
            return 0
        }
    }

    func indexPaths(for section: Int) -> [IndexPath] {
        switch sections[section] {
        case .balance:
            return balanceSectionRows.map { IndexPath(row: $0.rawValue, section: section) }
        case .gas:
            return gasSectionRows.map { IndexPath(row: $0.rawValue, section: section) }
        case .recipient:
            return recipientSectionRows.map { IndexPath(row: $0.rawValue, section: section) }
        case .amount:
            return []
        }
    }

    private var balanceSectionRows: [BalanceSectionRow] = BalanceSectionRow.allCases

    private var gasSectionRows: [GasSectionRow] {
        if isNonceSet {
            return GasSectionRow.allCases
        } else {
            return [.gasLimit, .gasPrice, .fee, .data]
        }
    }

    private var recipientSectionRows: [RecipientSectionRow] {
        if hasENSName {
            return RecipientSectionRow.allCases
        } else {
            return [.recipient]
        }
    }
}

private enum BalanceSectionRow: Int, CaseIterable {
    case address
}

private enum GasSectionRow: Int, CaseIterable {
    case gasLimit
    case gasPrice
    case fee
    case data
    case nonce
}

private enum RecipientSectionRow: Int, CaseIterable {
    case recipient
    case ens
}

struct ConfirmTransactionTableViewCellViewModel {
    let title: String
    let subTitle: String?
}
