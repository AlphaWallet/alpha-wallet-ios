// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct ImportMagicTokenViewControllerViewModel {
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

    var state: State
    var tokenHolder: TokenHolder?
    var cost: Cost?
    let server: RPCServer

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var headerTitle: String {
        return R.string.localizable.aClaimTokenTitle()
    }

    var activityIndicatorColor: UIColor {
        return Colors.appBackground
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
            return "x\(tokenHolder.tokens.count)"
        }
    }

    var city: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            return tokenHolder.values["locality"] as? String ?? emptyCity
        }
    }

    var category: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            if tokenHolder.hasAssetDefinition {
                return tokenHolder.values["category"] as? String ?? "N/A"
            } else {
                //For ERC75 tokens, display the contract's name as the "title". https://github.com/alpha-wallet/alpha-wallet-ios/issues/664
                return tokenHolder.name
            }
        }
    }

    var time: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            let value = tokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            return value.format("hh:mm")
        }
    }

    var teams: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            let countryA = tokenHolder.values["countryA"] as? String ?? ""
            let countryB = tokenHolder.values["countryB"] as? String ?? ""
            //While both will return emptyTeams, we want to be explicit about ising `emptyTeams`
            if countryA.isEmpty && countryB.isEmpty {
                return emptyTeams
            } else {
                return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
            }
        }
    }

    var match: String {
        guard let tokenHolder = tokenHolder else { return "" }
        let value = tokenHolder.values["match"] as? Int ?? 0
        return "M\(value)"
    }

    var venue: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            return tokenHolder.values["venue"] as? String ?? "N/A"
        }
    }

    var date: String {
        guard let tokenHolder = tokenHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            let value = tokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            return value.format("dd MMM yyyy")
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
            return Colors.appRed
        } else {
            return UIColor(red: 20, green: 20, blue: 20)
        }
    }

    var statusFont: UIFont {
        return Fonts.semibold(size: 25)!
    }

    var showCost: Bool {
        return showTokenRow
    }

    var ethCostLabelLabelText: String {
        return R.string.localizable.aClaimTokenEthCostLabelTitle()
    }

    var ethCostLabelLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var ethCostLabelLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
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
        return Colors.appBackground
    }

    var ethCostLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var dollarCostLabelLabelText: String {
        return R.string.localizable.aClaimTokenDollarCostLabelTitle()
    }

    var dollarCostLabelLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var dollarCostLabelLabelFont: UIFont {
        return Fonts.regular(size: 10)!
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
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var dollarCostLabelColor: UIColor {
        return Colors.darkGray
    }

    var dollarCostLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appActionButtonGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
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
        guard let cost = cost else { return true }
        switch cost {
        case .free:
            return true
        case .paid:
            return false
        }
    }

    var onlyShowTitle: Bool {
        switch state {
        case .validating, .processing:
            return true
        case .promptImport, .succeeded, .failed:
            return (teams.isEmpty && city.isEmpty) || (teams == emptyTeams && city == emptyCity)
        }
    }

    init(state: State, server: RPCServer) {
        self.state = state
        self.server = server
    }

    var actionButtonCornerRadius: CGFloat {
        return 16
    }

    var actionButtonShadowColor: UIColor {
        return Colors.appActionButtonShadow
    }

    var actionButtonShadowOffset: CGSize {
        return .init(width: 1, height: 2)
    }

    var actionButtonShadowOpacity: Float {
        return 0.3
    }

    var actionButtonShadowRadius: CGFloat {
        return 5
    }
}
