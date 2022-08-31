// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum URLServiceProvider {
    case discord
    case telegramCustomer
    case twitter
    case reddit
    case facebook
    case faq
    case github

    // TODO should probably change or remove `localURL` since iOS supports deep links now
    public var deepLinkURL: URL? {
        switch self {
        case .discord:
            return URL(string: "https://discord.com/invite/mx23YWRTYf")
        case .telegramCustomer:
            return URL(string: "https://t.me/AlphaWalletSupport")
        case .twitter:
            return URL(string: "twitter://user?screen_name=\(Constants.twitterUsername)")
        case .reddit:
            return URL(string: "reddit.com\(Constants.redditGroupName)")
        case .facebook:
            return URL(string: "fb://profile?id=\(Constants.facebookUsername)")
        case .faq, .github:
            return nil
        }
    }

    public var remoteURL: URL {
        switch self {
        case .discord:
            return URL(string: "https://discord.com/invite/mx23YWRTYf")!
        case .telegramCustomer:
            return URL(string: "https://t.me/AlphaWalletSupport")!
        case .twitter:
            return URL(string: "https://twitter.com/\(Constants.twitterUsername)")!
        case .reddit:
            return URL(string: "https://reddit.com/\(Constants.redditGroupName)")!
        case .facebook:
            return URL(string: "https://www.facebook.com/\(Constants.facebookUsername)")!
        case .faq:
            return URL(string: "https://alphawallet.com/faq/")!
        case .github:
            return URL(string: "https://github.com/AlphaWallet/alpha-wallet-ios/issues/new")!
        }
    }
}

public enum SocialNetworkUrlProvider {
    case discord
    case telegram
    case twitter
    case facebook
    case instagram

    public func deepLinkURL(user: String) -> URL? {
        switch self {
        case .discord:
            return URL(string: "https://discord.com/\(user)")
        case .telegram:
            return URL(string: "https://t.me/\(user)")
        case .twitter:
            return URL(string: "twitter://user?screen_name=\(user)")
        case .facebook:
            return URL(string: "https://www.facebook.com/\(user)")
        case .instagram:
            return URL(string: "instagram://user?username=\(user)")
        }
    }

    public func remoteURL(user: String) -> URL? {
        switch self {
        case .discord:
            return URL(string: "https://discord.com/\(user)")
        case .telegram:
            return URL(string: "https://t.me/\(user)")
        case .twitter:
            return URL(string: "https://twitter.com/\(user)")
        case .facebook:
            return URL(string: "https://www.facebook.com/\(user)")
        case .instagram:
            return URL(string: "https://instagram.com/\(user)")
        }
    }
}
