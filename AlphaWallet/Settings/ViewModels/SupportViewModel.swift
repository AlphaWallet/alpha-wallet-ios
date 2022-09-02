//
//  SupportViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2020.
//

import UIKit
import AlphaWalletFoundation

class SupportViewModel: NSObject {

    var title: String {
        R.string.localizable.settingsSupportTitle()
    }

    var rows: [SupportRow] = [.telegramCustomer, .discord, .email, .twitter, .github, .faq]

    func cellViewModel(indexPath: IndexPath) -> SettingTableViewCellViewModel {
        let row = rows[indexPath.row]
        return .init(titleText: row.title, subTitleText: nil, icon: row.image)
    }
}

enum SupportRow {
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
