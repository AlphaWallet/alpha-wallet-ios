//
//  AcceptDeepLinkViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.06.2022.
//

import Foundation
import AlphaWalletAddress
import AlphaWalletFoundation

final class AcceptDeepLinkViewModel: SectionProtocol {

    private let metadata: DeepLink.Metadata
    private let address: AlphaWallet.Address
    
    var openedSections: Set<Int> = .init()
    var connectionIconUrl: URL? { metadata.iconUrl }

    init(metadata: DeepLink.Metadata, address: AlphaWallet.Address) {
        self.metadata = metadata
        self.address = address
    }

    var navigationTitle: String {
        return R.string.localizable.acceptDeepLinkNavigationTitle()
    }

    var connectButtonTitle: String {
        return R.string.localizable.confirmPaymentConnectButtonTitle()
    }

    var rejectButtonTitle: String {
        return R.string.localizable.confirmPaymentRejectButtonTitle()
    }

    private var sections: [Section] {
        var sections: [Section] = [.name]
        if metadata.appUrl != nil {
            sections += [.url]
        }
        sections += [.note]

        return sections
    }

    func isSubviewsHidden(section: Int, row: Int) -> Bool {
        let isOpened = openedSections.contains(section)
        switch sections[section] {
        case .name, .url, .note:
            return isOpened
        }
    }

    var viewModels: [AcceptProposalViewModel.ViewModelType] {
        var viewModels: [AcceptProposalViewModel.ViewModelType] = []
        for section in sections.indices {
            switch sections[section] {
            case .name:
                let viewModel = TransactionConfirmationHeaderViewModel(title: .normal(metadata.name), headerName: sections[section].title, configuration: .init(section: section))
                viewModels += [.header(viewModel: viewModel, editButtonEnabled: false)]
            case .url:
                let appUrl = metadata.appUrl?.absoluteString ?? ""
                let viewModel = TransactionConfirmationHeaderViewModel(title: .normal(appUrl), headerName: sections[section].title, configuration: .init(section: section))
                viewModels += [.header(viewModel: viewModel, editButtonEnabled: false)]
            case .note:
                let note = R.string.localizable.acceptDeepLinkFieldNote(address.eip55String)
                let viewModel = TransactionConfirmationHeaderViewModel(title: .normal(note), headerName: sections[section].title, configuration: .init(section: section))

                viewModels += [.header(viewModel: viewModel, editButtonEnabled: false)]
            }
        }

        return viewModels
    }
}

extension AcceptDeepLinkViewModel {
    enum Section: CaseIterable {
        case name
        case note
        case url

        var title: String {
            switch self {
            case .name:
                return R.string.localizable.walletConnectConnectionNameTitle()
            case .note:
                return R.string.localizable.acceptDeepLinkFieldNoteTitle()
            case .url:
                return R.string.localizable.acceptDeepLinkFieldUrlTitle()
            }
        }
    }
}
