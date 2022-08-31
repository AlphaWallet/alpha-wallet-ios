//
//  ContactUsEmailResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation
import MessageUI
import AlphaWalletFoundation

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
