// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import AlphaWalletTokenScript

struct ImportMagicTokenViewModel {
    enum State {
        case validating
        case promptImport
        case processing
        case succeeded
        case failed(errorMessage: String)

        var hasCompleted: Bool {
            switch self {
            case .succeeded, .failed:
                return true
            case .validating, .processing, .promptImport:
                return false
            }
        }
    }
    enum Cost {
        case free
        case paid(eth: Decimal, dollar: Decimal?)
    }
    private let emptyCity = "N/A"
    private let emptyTeams = "-"
    private let server: RPCServer

    var state: State
    var tokenHolder: TokenHolder?
    var count: Decimal?
    var cost: Cost?

    var headerTitle: String {
        if let tokenHolder = tokenHolder {
            return R.string.localizable.aClaimTokenTitle(tokenHolder.name)
        } else {
            return R.string.localizable.aClaimTokenTitle(R.string.localizable.tokensTitlecase())
        }
    }

    var activityIndicatorColor: UIColor {
        return Configuration.Color.Semantic.defaultIcon
    }
    var showActivityIndicator: Bool {
        switch state {
        case .validating, .processing:
             return true
        case .promptImport, .succeeded, .failed:
             return false
        }
    }

    var showTokenRow: Bool {
        switch state {
        case .validating:
            return false
        case .processing, .promptImport, .succeeded, .failed:
            return true
        }
    }

    var tokenCount: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            if let count = count {
                return "x\(count)"
            } else {
                return "x\(tokenHolder.tokens.count)"
            }
        }
    }

    var city: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            return tokenHolder.values.localityStringValue ?? emptyCity
        }
    }

    var category: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            if tokenHolder.hasAssetDefinition {
                return tokenHolder.values.categoryStringValue ?? "N/A"
            } else {
                //For ERC75 tokens, display the contract's name as the "title". https://github.com/alpha-wallet/alpha-wallet-ios/issues/664
                return tokenHolder.name
            }
        }
    }

    var isMeetupContract: Bool {
        guard let tokenHolder = tokenHolder else { return false }
        return tokenHolder.isSpawnableMeetupContract
    }

    var time: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            let value = tokenHolder.values.timeGeneralisedTimeValue ?? GeneralisedTime()
            return value.format("hh:mm")
        }
    }

    var teams: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            if isMeetupContract && tokenHolder.values["expired"] != nil {
                return ""
            } else {
                let countryA = tokenHolder.values.countryAStringValue ?? ""
                let countryB = tokenHolder.values.countryBStringValue ?? ""
                //While both will return emptyTeams, we want to be explicit about using `emptyTeams`
                if countryA.isEmpty && countryB.isEmpty {
                    return emptyTeams
                } else {
                    return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
                }
            }
        }
    }

    var match: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if tokenHolder.values["section"] != nil {
            if let section = tokenHolder.values.sectionStringValue {
                return "S\(section)"
            } else {
                return "S0"
            }
        } else {
            let value = tokenHolder.values.matchIntValue ?? 0
            return "M\(value)"
        }
    }

    var venue: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            return tokenHolder.values.venueStringValue ?? ""
        }
    }

    var date: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            let value = tokenHolder.values.timeGeneralisedTimeValue ?? GeneralisedTime()
            return value.formatAsShortDateString()
        }
    }

    var numero: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if let num = tokenHolder.values.numeroIntValue {
            return String(num)
        } else {
            return "N/A"
        }
    }

    var statusText: String {
        switch state {
        case .validating:
            return R.string.localizable.aClaimTokenValidatingTitle()
        case .promptImport:
            return R.string.localizable.aClaimTokenPromptImportTitle()
        case .processing:
            return R.string.localizable.aClaimTokenInProgressTitle()
        case .succeeded:
            return R.string.localizable.aClaimTokenSuccessTitle()
        case .failed(let errorMessage):
            return errorMessage
        }
    }

    var statusColor: UIColor {
        if case .failed = state {
            return Configuration.Color.Semantic.fail
        } else {
            return Configuration.Color.Semantic.pass
        }
    }

    var statusFont: UIFont {
        return Fonts.regular(size: 25)
    }

    var showCost: Bool {
        return showTokenRow
    }

    var ethCostLabelLabelText: String {
        return R.string.localizable.aClaimTokenEthCostLabelTitle()
    }

    var ethCostLabelLabelColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }

    var ethCostLabelLabelFont: UIFont {
        return Fonts.semibold(size: 21)
    }

    var ethCostLabelText: String {
        guard let cost = cost else { return R.string.localizable.aClaimTokenEthCostFreeTitle() }
        switch cost {
        case .free:
            return R.string.localizable.aClaimTokenEthCostFreeTitle()
        case .paid(let ethCost, _):
            return "\(ethCost) \(server.symbol)"
        }
    }

    var ethCostLabelColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }

    var ethCostLabelFont: UIFont {
        return Fonts.semibold(size: 21)
    }

    var dollarCostLabelLabelText: String {
        return R.string.localizable.aClaimTokenDollarCostLabelTitle()
    }

    var dollarCostLabelLabelColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }

    var dollarCostLabelLabelFont: UIFont {
        return Fonts.regular(size: 10)
    }

    var dollarCostLabelText: String {
        guard let cost = cost else { return "" }
        switch cost {
        case .free:
            return ""
        case .paid(_, let dollarCost):
            guard let dollarCost = dollarCost, let dollarCostAsDouble = Double(dollarCost.description) else { return "" }
            let string = StringFormatter().currency(with: dollarCostAsDouble, and: "USD")
            return "$\(string)"
        }
    }

    var dollarCostLabelBackgroundColor: UIColor {
        return Configuration.Color.Semantic.tableViewSpecialBackground
    }

    var dollarCostLabelColor: UIColor {
        return Configuration.Color.Semantic.alternativeText
    }

    var dollarCostLabelFont: UIFont {
        return Fonts.regular(size: 21)
    }

    var showActionButton: Bool {
        switch state {
        case .promptImport:
            return true
        case .validating, .processing, .succeeded, .failed:
            return false
        }
    }

    var actionButtonTitle: String {
        switch state {
        case .validating:
            return ""
        case .promptImport:
            if transactionIsFree {
                return R.string.localizable.aClaimTokenImportButtonTitle()
            } else {
                return R.string.localizable.aClaimTokenPurchaseButtonTitle()
            }
        case .processing:
            return ""
        case .succeeded:
            return ""
        case .failed:
            return ""
        }
    }

    var cancelButtonTitle: String {
        switch state {
        case .validating, .promptImport, .processing:
            return R.string.localizable.cancel()
        case .succeeded, .failed:
            return R.string.localizable.done()
        }
    }

    var transactionIsFree: Bool {
        guard let cost = cost else { return true }
        switch cost {
        case .free:
            return true
        case .paid:
            return false
        }
    }

    var hideDollarCost: Bool {
        return dollarCostLabelText.isEmpty
    }

    var onlyShowTitle: Bool {
        switch state {
        case .validating, .processing:
            return true
        case .promptImport, .succeeded, .failed:
            if let tokenHolder = tokenHolder, tokenHolder.isSpawnableMeetupContract {
                //Not the best check, but we assume that even if the data is just partially available, we can show something
                //TODO get rid of this. Do we even use "building" as spawnable check anymore? Testing `is String` is wrong anyway. But probably harmless for now
                if tokenHolder.values.buildingSubscribableValue?.value?.stringValue != nil {
                    return false
                } else {
                    return true
                }
            } else {
                return (teams.isEmpty && city.isEmpty) || (teams == emptyTeams && city == emptyCity)
            }
        }
    }

    init(state: State, server: RPCServer) {
        self.state = state
        self.server = server
    }
}
