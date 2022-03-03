// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

enum URLServiceProvider {
    case discord
    case telegramCustomer
    case twitter
    case reddit
    case facebook
    case faq
    case github

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

    // TODO should probably change or remove `localURL` since iOS supports deep links now
    var deepLinkURL: URL? {
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

    var remoteURL: URL {
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

enum SocialNetworkUrlProvider {
    case discord
    case telegram
    case twitter
    case facebook
    case instagram

    static func resolveUrl(for user: String, urlProvider: SocialNetworkUrlProvider) -> URL? {
        if let url = URL(string: user), user.isValidURL {
            return url
        }

        guard let deepLink = urlProvider.deepLinkURL(user: user), UIApplication.shared.canOpenURL(deepLink) else {
            if let url = urlProvider.remoteURL(user: user) {
                return url
            } else {
                return URL(string: user)
            }
        }
        return deepLink
    }

    func deepLinkURL(user: String) -> URL? {
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

    func remoteURL(user: String) -> URL? {
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

import MessageUI

final class ContactUsEmailResolver: NSObject {

    private var emailTemplate: String {
        return """
               \n\n\n
               \(R.string.localizable.aHelpContactEmailHelpfulToDevelopers())
               \(R.string.localizable.aHelpContactEmailIosVersion(UIDevice.current.systemVersion))
               \(R.string.localizable.aHelpContactEmailDeviceModel(UIDevice.current.model))
               \(R.string.localizable.aHelpContactEmailAppVersion("\(Bundle.main.fullVersion). \(TokenScript.supportedTokenScriptNamespaceVersion)"))
               \(R.string.localizable.aHelpContactEmailLocale(Locale.preferredLanguages.first ?? ""))
               """
    }

    func present(from viewController: UIViewController, attachments: [EmailAttachment]) {
        if MFMailComposeViewController.canSendMail() {
            let mc = getMFMailComposeViewController()
            mc.mailComposeDelegate = self

            for attachment in attachments {
                mc.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
            }

            viewController.present(mc, animated: true)
        } else {
            viewController.displayError(message: R.string.localizable.emailNotConfigured())
        }
    }

    private func getMFMailComposeViewController() -> MFMailComposeViewController {
        let mc = MFMailComposeViewController()

        mc.setToRecipients([Constants.supportEmail])
        mc.setSubject(R.string.localizable.aHelpContactEmailSubject())
        mc.setMessageBody(emailTemplate, isHTML: false)
        mc.makePresentationFullScreenForiOS13Migration()

        return mc
    }
}

extension ContactUsEmailResolver: MFMailComposeViewControllerDelegate {

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

typealias EmailAttachment = (data: Data, mimeType: String, fileName: String)
extension Logger {
    static var logFilesAttachments: [EmailAttachment] {
        return Self.logFileURLs.compactMap { url -> EmailAttachment? in
            guard let data = try? Data(contentsOf: url), let mimeType = url.mimeType else { return nil }

            return (data, mimeType, url.lastPathComponent)
        }
    }
}
