// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct ImportTicketViewControllerViewModel {
    enum State {
        case validating
        case promptImport
        case processing
        case succeeded
        case failed(errorMessage: String)
    }
    var state: State
    var ticketHolder: TicketHolder?
    var ethCost: String?
    var dollarCost: String?

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
        if case let .validating = state {
            return ""
        } else {
            return "x\(ticketHolder.tickets.count)"
        }
    }

    var title: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case let .validating = state {
            return ""
        } else {
            return ticketHolder.name
        }
    }

    var seatRange: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case let .validating = state {
            return ""
        } else {
            return ticketHolder.seatRange
        }
    }

    var city: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case let .validating = state {
            return ""
        } else {
            return ticketHolder.city
        }
    }

    var venue: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case let .validating = state {
            return ""
        } else {
            return ticketHolder.venue
        }
    }

    var date: String {
        guard let ticketHolder = ticketHolder else { return "" }
        if case let .validating = state {
            return ""
        } else {
            //TODO Should format be localized?
            return ticketHolder.date.format("dd MMM yyyy")
        }
    }

    var showTicketRowIcons: Bool {
        if case let .validating = state {
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
        case .failed:
            return R.string.localizable.aClaimTicketFailedTitle()
        }
    }

    var statusColor: UIColor {
        return UIColor(red: 20, green: 20, blue: 20)
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
        guard let ethCost = ethCost else { return R.string.localizable.aClaimTicketEthCostFreeTitle() }
        if ethCost.isEmpty {
            return R.string.localizable.aClaimTicketEthCostFreeTitle()
        } else {
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
        guard let dollarCost = dollarCost else { return "" }
        if dollarCost.isEmpty {
            return ""
        } else {
            return "$\(dollarCost)"
        }
    }

    var showDollarCostLabel: Bool {
        return !transactionIsFree
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
            return R.string.localizable.aClaimTicketDoneButtonTitle()
        }
    }

    var transactionIsFree: Bool {
        guard let ethCost = ethCost else { return true }
        return ethCost.isEmpty
    }

    init(state: State) {
        self.state = state
    }
}
