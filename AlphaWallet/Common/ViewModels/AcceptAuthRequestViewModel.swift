// Copyright © 2023 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

enum AuthRequestResult {
    case accept(RPCServer)
    case cancel
}

final class AcceptAuthRequestViewModel: ExpandableSection {
    private let analytics: AnalyticsLogger
    private let authRequest: AlphaWallet.WalletConnect.AuthRequest
    var openedSections: Set<Int> = .init()
    var server: RPCServer {
        if let chainId = Int(authRequest.chainId) {
            return RPCServer(chainID: chainId)
        } else {
            return RPCServer.main
        }
    }

    init(authRequest: AlphaWallet.WalletConnect.AuthRequest, analytics: AnalyticsLogger) {
        self.authRequest = authRequest
        self.analytics = analytics
    }

    var title: String {
        return R.string.localizable.walletConnectAuthTitle(server.displayName)
    }

    var connectButtonTitle: String {
        return R.string.localizable.confirmPaymentConnectButtonTitle()
    }

    var rejectButtonTitle: String {
        return R.string.localizable.confirmPaymentRejectButtonTitle()
    }

    private var sections: [Section] {
        let sections: [Section] = [.statement, .domain, .aud, .nonce, .chain, .iat]
        return sections
    }

    func isSubviewsHidden(section: Int, row: Int) -> Bool {
        return false
    }

    private func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
        switch sections[section] {
        case .domain:
            return .init(title: .normal(authRequest.domain), headerName: sections[section].title, viewState: .init(section: section))
        case .aud:
            return .init(title: .normal(authRequest.aud), headerName: sections[section].title, viewState: .init(section: section))
        case .chain:
            return .init(title: .normal(server.displayName), headerName: sections[section].title, viewState: .init(section: section))
        case .iat:
            let dateString = functional.formatDateStringForDisplay(authRequest.iat)
            return .init(title: .normal(dateString), headerName: sections[section].title, viewState: .init(section: section))
        case .nonce:
            return .init(title: .normal(authRequest.nonce), headerName: sections[section].title, viewState: .init(section: section))
        case .statement:
            return .init(title: .normal(authRequest.statement), headerName: sections[section].title, viewState: .init(section: section))
        }
    }

    var viewModels: [AcceptProposalViewModel.ViewModelType] {
        var _viewModels: [AcceptProposalViewModel.ViewModelType] = []
        for (sectionIndex, section) in sections.enumerated() {
            switch section {
            case .domain, .aud, .nonce, .iat, .statement, .chain:
                _viewModels += [.header(viewModel: headerViewModel(section: sectionIndex), editButtonEnabled: false)]
            }
        }
        return _viewModels
    }

    enum functional {}
}

fileprivate extension AcceptAuthRequestViewModel.functional {
    static func formatDateStringForDisplay(_ inputString: String) -> String {
        let inDateFormatter = DateFormatter()
        inDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        inDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        inDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = inDateFormatter.date(from: inputString) {
            let outDateFormatter = Date.formatter(with: "dd MMM yyyy h:mm:ss a")
            return outDateFormatter.string(from: date)
        } else {
            return inputString
        }
    }
}

// MARK: Analytics
extension AcceptAuthRequestViewModel {
    func logAuthAccept() {
        analytics.log(action: Analytics.Action.walletConnectAuthAccept, properties: [
            Analytics.Properties.chain.rawValue: server.chainID
        ])
    }

    func logAuthCancel() {
        analytics.log(action: Analytics.Action.walletConnectAuthCancel)
    }
}

extension AcceptAuthRequestViewModel {
    enum Section: CaseIterable {
        case domain
        case aud
        case nonce
        case chain
        case iat
        case statement

        var title: String {
            switch self {
            case .domain:
                return R.string.localizable.walletConnectAuthDomainTitle()
            case .aud:
                return R.string.localizable.walletConnectAuthUriTitle()
            case .chain:
                return R.string.localizable.walletConnectAuthServerTitle()
            case .iat:
                return R.string.localizable.walletConnectAuthIssuedAtTitle()
            case .nonce:
                return R.string.localizable.walletConnectAuthNonceTitle()
            case .statement:
                return R.string.localizable.walletConnectAuthStatementTitle()
            }
        }
    }
}