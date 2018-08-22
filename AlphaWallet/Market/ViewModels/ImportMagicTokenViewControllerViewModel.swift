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

    var state: State
    var ticketHolder: TokenHolder?
    var cost: Cost?

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var headerTitle: String {
        return R.string.localizable.aClaimTicketTitle()
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

    var showTicketRow: Bool {
        switch state {
        case .validating:
            return false
        case .processing, .promptImport, .succeeded, .failed:
            return true
        }
    }

    var ticketCount: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            return "x\(ticketHolder.tickets.count)"
        }
    }

    var city: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            return ticketHolder.values["locality"] as? String ?? "N/A"
        }
    }

    var category: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            return ticketHolder.values["category"] as? String ?? "N/A"
        }
    }

    var time: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            let value = ticketHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            return value.format("hh:mm")
        }
    }

    var teams: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            let countryA = ticketHolder.values["countryA"] as? String ?? ""
            let countryB = ticketHolder.values["countryB"] as? String ?? ""
            return R.string.localizable.aWalletTicketTokenMatchVs(countryA, countryB)
        }
    }

    var match: String {
        guard let ticketHolder = ticketHolder else { return "" }
        let value = ticketHolder.values["match"] as? Int ?? 0
        return "M\(value)"
    }

    var venue: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            return ticketHolder.values["venue"] as? String ?? "N/A"
        }
    }

    var date: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case .validating = state {
            return ""
        } else {
            let value = ticketHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            return value.format("dd MMM yyyy")
        }
    }

    var showTicketRowIcons: Bool {
        if case .validating = state {
            return false
        } else {
            return true
        }
    }

    var statusText: String {
        switch state {
        case .validating:
            return R.string.localizable.aClaimTicketValidatingTitle()
        case .promptImport:
            return R.string.localizable.aClaimTicketPromptImportTitle()
        case .processing:
            return R.string.localizable.aClaimTicketInProgressTitle()
        case .succeeded:
            return R.string.localizable.aClaimTicketSuccessTitle()
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
        return showTicketRow
    }

    var ethCostLabelLabelText: String {
        return R.string.localizable.aClaimTicketEthCostLabelTitle()
    }

    var ethCostLabelLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var ethCostLabelLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var ethCostLabelText: String {
        guard let cost = cost else { return R.string.localizable.aClaimTicketEthCostFreeTitle() }
        switch cost {
        case .free:
            return R.string.localizable.aClaimTicketEthCostFreeTitle()
        case .paid(let ethCost, _):
            return "\(ethCost) ETH"
        }
    }

    var ethCostLabelColor: UIColor {
        return Colors.appBackground
    }

    var ethCostLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var dollarCostLabelLabelText: String {
        return R.string.localizable.aClaimTicketDollarCostLabelTitle()
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
            guard let dollarCost = dollarCost else { return "" }
            return "$\(dollarCost)"
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
        return Colors.appHighlightGreen
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
                return R.string.localizable.aClaimTicketImportButtonTitle()
            } else {
                return R.string.localizable.aClaimTicketPurchaseButtonTitle()
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

    init(state: State) {
        self.state = state
    }
}
