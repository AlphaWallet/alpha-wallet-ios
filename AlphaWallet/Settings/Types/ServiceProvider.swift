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

    var title: String {
        switch self {
        case .discord:
            return "Discord"
        case .telegramCustomer:
            return "Telegram (Customer Support)"
        case .twitter:
            return "Twitter"
        case .reddit:
            return "Reddit"
        case .facebook:
            return "Facebook"
        case .faq:
            return "faq".uppercased()
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
        case .faq:
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

    private lazy var mailComposer: MFMailComposeViewController = {
        let mailComposer = MFMailComposeViewController()

        mailComposer.setToRecipients([Constants.supportEmail])
        mailComposer.setSubject(R.string.localizable.aHelpContactEmailSubject())
        mailComposer.setMessageBody(emailTemplate, isHTML: false)
        mailComposer.makePresentationFullScreenForiOS13Migration()

        return mailComposer
    }()

    func present(from viewController: UIViewController, attachments: [EmailAttachment]) {
        if MFMailComposeViewController.canSendMail() {
            mailComposer.mailComposeDelegate = self

            for attachment in attachments {
                mailComposer.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
            }

            viewController.present(mailComposer, animated: true)
        }
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
