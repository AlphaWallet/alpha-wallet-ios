// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt

struct AaveDebtTokenViewControllerViewModel: HardcodedTokenViewControllerViewModel {
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
            if let balance = values["currentBorrowBalance"]?.uintValue {
                //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                let amount = EtherNumberFormatter.short.string(from: BigInt(balance), decimals: 18)
                return "\(amount) DAI"
            } else {
                return "-"
            }
        }
        self.sections = [
            (section: R.string.localizable.aaveDebtTokenViewDebt(), rows: [
                (title: R.string.localizable.aaveDebtTokenViewRowDefiProvider(), formatter: { _ in
                    R.string.localizable.aaveDebtTokenViewRowDefiProviderAave()
                }, progressBlock: nil),
                (title: R.string.localizable.aaveDebtTokenViewRowBorrowed(), formatter: { values in
                    if let value = values["principalBorrowBalance"]?.uintValue {
                        //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                        let amount = EtherNumberFormatter.short.string(from: BigInt(value), decimals: 18)
                        return "\(amount) DAI"
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
                (title: R.string.localizable.aaveDebtTokenViewRowInterestToDate(), formatter: { values in
                    if let current = values["currentBorrowBalance"]?.uintValue, let principal = values["principalBorrowBalance"]?.uintValue {
                        //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                        let value = EtherNumberFormatter.short.string(from: BigInt(current - principal), decimals: 18).doubleValue
                        if let value = NumberFormatter.crypto.string(from: value) {
                            return "\(value) DAI"
                        } else {
                            return "-"
                        }
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
                (title: R.string.localizable.aaveDebtTokenViewRowInterestRate(), formatter: { values in
                    if let borrowRate: Double = values["borrowRate"]?.uintValue.flatMap({ EtherNumberFormatter.short.string(from: BigInt($0), decimals: 25) })?.doubleValue,
                       let borrowRateMode = values["borrowRateMode"]?.uintValue {
                        if let borrowRate = NumberFormatter.crypto.string(from: borrowRate) {
                            if borrowRateMode == BigUInt(2) {
                                return R.string.localizable.aaveDebtTokenViewRowInterestRateFloat(String(borrowRate))
                            } else {
                                return R.string.localizable.aaveDebtTokenViewRowInterestRateFixed(String(borrowRate))
                            }
                        } else {
                            return "-"
                        }
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
            ]),
            (section: R.string.localizable.hardcodedTokenCardCredit(), rows: [
                (title: R.string.localizable.hardcodedTokenCardCreditRowYourCollateral(), formatter: { values in
                    if let value = values["totalCollateralETH"]?.uintValue {
                        //TODO fix for activities. Hardcoded decimals and token symbol. Watch out which token this is for. Should use a TokenScript token attribute for the decimals too, probably
                        let amount = EtherNumberFormatter.short.string(from: BigInt(value), decimals: 18)
                        return "\(amount) ETH"
                    } else {
                        return "-"
                    }
                }, progressBlock: nil),
                (title: R.string.localizable.hardcodedTokenCardCreditRowLoanToValue(), formatter: { values in
                    if let value = values["ltv"]?.uintValue {
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
