//
//  SupportViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2020.
//

import UIKit
import AlphaWalletFoundation
import AlphaWalletLogger
import Combine

struct SupportViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let selection: AnyPublisher<IndexPath, Never>
}

struct SupportViewModelOutput {
    let viewState: AnyPublisher<SupportViewModel.ViewState, Never>
    let supportAction: AnyPublisher<SupportViewModel.SupportAction, Never>
}

class SupportViewModel: NSObject {
    private let analytics: AnalyticsLogger
    private let supportedRows: [SupportCase] = [.telegramCustomer, .discord, .email, .twitter, .github, .faq]

    init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    func transform(input: SupportViewModelInput) -> SupportViewModelOutput {
        let viewState = input.willAppear
            .map { _ in self.supportedRows.map { SettingTableViewCellViewModel(titleText: $0.title, subTitleText: nil, icon: $0.image) } }
            .map { self.buildSnapshot(for: [SectionViewModel(section: .rows, views: $0)]) }
            .map { ViewState(snapshot: $0) }
            .eraseToAnyPublisher()

        let supportAction = input.selection
            .compactMap { self.buildSupportAction(for: self.supportedRows[$0.row]) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, supportAction: supportAction)
    }

    private func buildSnapshot(for viewModels: [SectionViewModel]) -> SupportViewModel.Snapshot {
        var snapshot = NSDiffableDataSourceSnapshot<SupportViewModel.Section, SettingTableViewCellViewModel>()
        let sections = viewModels.map { $0.section }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.views, toSection: each.section)
        }

        return snapshot
    }

    private func buildSupportAction(for row: SupportCase) -> SupportAction? {
        switch row {
        case .faq:
            logAccessFaq()
            return .openUrl(.faq)
        case .discord:
            logAccessDiscord()
            return .openUrl(.discord)
        case .telegramCustomer:
            logAccessTelegramCustomerSupport()
            return .openUrl(.telegramCustomer)
        case .twitter:
            logAccessTwitter()
            return .openUrl(.twitter)
        case .reddit:
            logAccessReddit()
            return .openUrl(.reddit)
        case .facebook:
            logAccessFacebook()
            return .openUrl(.facebook)
        case .blog:
            break
        case .github:
            logAccessGithub()
            return .openUrl(.github)
        case .email:
            let attachments = Features.current.isAvailable(.isAttachingLogFilesToSupportEmailEnabled) ? DDLogger.logFilesAttachments : []
            return .shareAttachments(attachments: attachments)
        }

        return nil
    }

    private func logAccessFaq() {
        analytics.log(navigation: Analytics.Navigation.faq)
    }

    private func logAccessDiscord() {
        analytics.log(navigation: Analytics.Navigation.discord)
    }

    private func logAccessTelegramCustomerSupport() {
        analytics.log(navigation: Analytics.Navigation.telegramCustomerSupport)
    }

    private func logAccessTwitter() {
        analytics.log(navigation: Analytics.Navigation.twitter)
    }

    private func logAccessReddit() {
        analytics.log(navigation: Analytics.Navigation.reddit)
    }

    private func logAccessFacebook() {
        analytics.log(navigation: Analytics.Navigation.facebook)
    }

    private func logAccessGithub() {
        analytics.log(navigation: Analytics.Navigation.github)
    }
}

extension SupportViewModel {
    typealias Snapshot = NSDiffableDataSourceSnapshot<SupportViewModel.Section, SettingTableViewCellViewModel>
    typealias DataSource = UITableViewDiffableDataSource<SupportViewModel.Section, SettingTableViewCellViewModel>

    struct ViewState {
        let snapshot: SupportViewModel.Snapshot
        let animatingDifferences: Bool = false
        let title: String = R.string.localizable.settingsSupportTitle()
    }

    struct SectionViewModel {
        let section: SupportViewModel.Section
        let views: [SettingTableViewCellViewModel]
    }

    enum Section: Int, Hashable, CaseIterable {
        case rows
    }

    enum SupportCase: String {
        case discord
        case telegramCustomer
        case twitter
        case reddit
        case facebook
        //TODO remove if unused
        case blog
        case faq
        case github
        case email
    }

    enum SupportAction {
        case openUrl(URLServiceProvider)
        case shareAttachments(attachments: [EmailAttachment])
    }
}

extension SupportViewModel.SupportCase {

    var urlProvider: URLServiceProvider? {
        switch self {
        case .discord:
            return URLServiceProvider.discord
        case .telegramCustomer:
            return URLServiceProvider.telegramCustomer
        case .twitter:
            return URLServiceProvider.twitter
        case .reddit:
            return URLServiceProvider.reddit
        case .facebook:
            return URLServiceProvider.facebook
        case .faq:
            return URLServiceProvider.faq
        case .github:
            return URLServiceProvider.github
        case .blog, .email:
            return nil
        }
    }

    var title: String {
        switch self {
        case .discord:
            return URLServiceProvider.discord.title
        case .telegramCustomer:
            return URLServiceProvider.telegramCustomer.title
        case .twitter:
            return URLServiceProvider.twitter.title
        case .reddit:
            return URLServiceProvider.reddit.title
        case .facebook:
            return URLServiceProvider.facebook.title
        case .faq:
            return URLServiceProvider.faq.title
        case .blog:
            return R.string.localizable.supportBlogTitle()
        case .email:
            return R.string.localizable.supportEmailTitle()
        case .github:
            return URLServiceProvider.github.title
        }
    }

    var image: UIImage? {
        switch self {
        case .email:
            return R.image.iconsSettingsEmail()
        case .discord:
            return URLServiceProvider.discord.image
        case .telegramCustomer:
            return URLServiceProvider.telegramCustomer.image
        case .twitter:
            return URLServiceProvider.twitter.image
        case .reddit:
            return URLServiceProvider.reddit.image
        case .facebook:
            return URLServiceProvider.facebook.image
        case .faq:
            return R.image.settings_faq()
        case .blog:
            return R.image.settings_faq()
        case .github:
            return URLServiceProvider.github.image
        }
    }
}

extension URLServiceProvider {

    var title: String {
        switch self {
        case .discord:
            return R.string.localizable.urlDiscord()
        case .telegramCustomer:
            return R.string.localizable.urlTelegramCustomer()
        case .twitter:
            return R.string.localizable.urlTwitter()
        case .reddit:
            return R.string.localizable.urlReddit()
        case .facebook:
            return R.string.localizable.urlFacebook()
        case .faq:
            return R.string.localizable.urlFaq().uppercased()
        case .github:
            return R.string.localizable.urlGithub()
        }
    }

    var image: UIImage? {
        switch self {
        case .discord:
            return R.image.iconsSettingsDiscord()
        case .telegramCustomer:
            return R.image.settings_telegram()
        case .twitter:
            return R.image.settings_twitter()
        case .reddit:
            return R.image.settings_reddit()
        case .facebook:
            return R.image.settings_facebook()
        case .faq:
            return R.image.settings_faq()
        case .github:
            return R.image.iconsSettingsGithub()
        }
    }
}
