// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt

struct AEthTokenViewControllerViewModel: HardcodedTokenViewControllerViewModel {
    let title: String
    let description: String
    let transferType: TransferType
    let session: WalletSession
    let assetDefinitionStore: AssetDefinitionStore
    let headerValueFormatter: HardcodedTokenCardRowFormatter
    var sections: [(section: String, rows: [(title: String, formatter: HardcodedTokenCardRowFormatter, progressBlock: HardcodedTokenCardRowFloatBlock?)])]

    init(title: String, description: String, transferType: TransferType, session: WalletSession, assetDefinitionStore: AssetDefinitionStore) {
        self.title = title
        self.description = description
        self.transferType = transferType
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
        self.headerValueFormatter = { values in
            if let value = values["aTokenBalance"]?.uintValue {
                //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                let amount = EtherNumberFormatter.short.string(from: BigInt(value), decimals: 18)
                return "\(amount) aETH"
            } else {
                return "-"
            }
        }
        self.sections = [
            (section: R.string.localizable.aEthTokenViewBalance(), rows: [
                (title: R.string.localizable.aEthTokenViewRowTotalDepositedAndInterest(), formatter: { values in
                    if let value = values["aTokenBalance"]?.uintValue {
                        //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                        let amount = EtherNumberFormatter.short.string(from: BigInt(value), decimals: 18)
                        return "\(amount) aETH"
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
                (title: R.string.localizable.aEthTokenViewRowBorrowed(), formatter: { values in
                    if let value = values["totalBorrows"]?.uintValue {
                        //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                        let amount = EtherNumberFormatter.short.string(from: BigInt(value), decimals: 18)
                        return "\(amount) ETH"
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
                (title: R.string.localizable.aEthTokenViewRowAvailableToSend(), formatter: { values in
                    if let value = values["availableBorrowsETH"]?.uintValue {
                        //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                        let amount = EtherNumberFormatter.short.string(from: BigInt(value), decimals: 18)
                        return "\(amount) aETH"
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
            ]),
            (section: R.string.localizable.hardcodedTokenCardCredit(), rows: [
                (title: R.string.localizable.hardcodedTokenCardCreditRowYourCollateral(), formatter: { values in
                    if let value = values["totalCollateral"]?.uintValue {
                        //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                        let amount = EtherNumberFormatter.short.string(from: BigInt(value), decimals: 18)
                        return "\(amount) ETH"
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
                (title: R.string.localizable.hardcodedTokenCardCreditRowLoanToValue(), formatter: { values in
                    if let value = values["loanToValue"]?.uintValue {
                        //TODO fix for activities. Hardcoded decimals. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                        return "\(value)%"
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
                (title: R.string.localizable.hardcodedTokenCardCreditRowBorrowingPowerUsed(), formatter: { values in
                    //TODO fix for activities. Hardcoded decimals. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                    if let borrows = values["totalBorrows"]?.uintValue, let available = values["availableBorrowsETH"]?.uintValue {
                        if (borrows + available) == 0 {
                            return "-"
                        } else {
                            let numerator = EtherNumberFormatter.short.string(from: BigInt(borrows), decimals: 18).doubleValue
                            let denominator = EtherNumberFormatter.short.string(from: BigInt(borrows + available), decimals: 18).doubleValue
                            let value = numerator / denominator
                            return NumberFormatter.percent.string(from: value) ?? "-"
                        }
                    } else {
                        return "-"
                    }
                }, progressBlock: { values in
                    //TODO fix for activities. Hardcoded decimals. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                    if let borrows = values["totalBorrows"]?.uintValue, let available = values["availableBorrowsETH"]?.uintValue {
                        if (borrows + available) == 0 {
                            return 0
                        } else {
                            let numerator = EtherNumberFormatter.short.string(from: BigInt(borrows), decimals: 18).doubleValue
                            let denominator = EtherNumberFormatter.short.string(from: BigInt(borrows + available), decimals: 18).doubleValue
                            let value = numerator / denominator
                            return Float(value)
                        }
                    } else {
                        return 0
                    }
                }),
            ])
        ]
    }
}
