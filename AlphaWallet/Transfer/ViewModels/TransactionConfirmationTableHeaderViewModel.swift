//
//  TransactionConfirmationHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.07.2020.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct TransactionConfirmationHeaderViewModel {
    let title: String?
    let headerName: String?
    let details: String?
    var viewState: ViewState
    let titleIcon: ImagePublisher
    var chevronImage: UIImage? {
        let image = viewState.isOpened ? R.image.expand() : R.image.not_expand()
        return image?.withRenderingMode(.alwaysTemplate)
    }

    var titleAlpha: CGFloat {
        if viewState.shouldHideChevron {
            return 1.0
        } else {
            return viewState.isOpened ? 0.0 : 1.0
        }
    }

    var titleAttributedString: NSAttributedString? {
        guard let title = title else { return nil }
        
        return NSAttributedString(string: title, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .font: Fonts.regular(size: 17)
        ])
    }

    var headerNameAttributedString: NSAttributedString? {
        guard let name = headerName else { return nil }

        return NSAttributedString(string: name, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 13)
        ])
    }

    var detailsAttributedString: NSAttributedString? {
        guard let details = details else { return nil }

        return NSAttributedString(string: details, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Fonts.regular(size: 15)
        ])
    }

    init(title: Title,
         headerName: String?,
         details: String? = nil,
         titleIcon: ImagePublisher = .just(nil),
         viewState: TransactionConfirmationHeaderViewModel.ViewState) {

        switch title {
        case .normal(let title):
            self.title = title
            self.titleIcon = titleIcon
        case .warning(let title):
            self.title = title
            self.titleIcon = .just(R.image.gasWarning().flatMap { ImageOrWebImageUrl<Image>.image($0) })
        }
        self.headerName = headerName
        self.details = details
        self.viewState = viewState
    }
}

extension TransactionConfirmationHeaderViewModel {
    struct ViewState {
        var isOpened: Bool = false
        let section: Int
        var shouldHideChevron: Bool = true
    }

    enum Title {
        case normal(String?)
        case warning(String)
    }
}
