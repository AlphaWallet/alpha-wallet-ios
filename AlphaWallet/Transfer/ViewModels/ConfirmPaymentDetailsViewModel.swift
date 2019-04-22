// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct ConfirmPaymentDetailsViewModel {
    private let transaction: PreviewTransaction
    private let currentBalance: BalanceProtocol?
    private let currencyRate: CurrencyRate?
    private let server: RPCServer
    private let fullFormatter = EtherNumberFormatter.full

    private var gasViewModel: GasViewModel {
        return GasViewModel(fee: totalFee, symbol: server.symbol, currencyRate: currencyRate, formatter: fullFormatter)
    }

    private var totalFee: BigInt {
        return transaction.gasPrice * transaction.gasLimit
    }

    private var gasLimit: BigInt {
        return transaction.gasLimit
    }

    init(
        transaction: PreviewTransaction,
        server: RPCServer,
        currentBalance: BalanceProtocol?,
        currencyRate: CurrencyRate?
    ) {
        self.transaction = transaction
        self.currentBalance = currentBalance
        self.server = server
        self.currencyRate = currencyRate
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

    var gasPriceText: String {
        let unit = UnitConfiguration.gasPriceUnit
        let amount = fullFormatter.string(from: transaction.gasPrice, units: UnitConfiguration.gasPriceUnit)
        return  String(
            format: "%@ %@",
            amount,
            unit.name
        )
    }

    var feeTitle: String {
        return R.string.localizable.confirmPaymentGasFeeLabelTitle()
    }

    var feeText: String {
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

    var gasLimitText: String {
        return gasLimit.description
    }

    var amountTextColor: UIColor {
        return Colors.red
    }

    var dataTitle: String {
        return R.string.localizable.confirmPaymentDataLabelTitle()
    }

    var dataText: String {
        return transaction.data.description
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
}
