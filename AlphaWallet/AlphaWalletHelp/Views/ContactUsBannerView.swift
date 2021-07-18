// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import MessageUI

protocol ContactUsBannerViewDelegate: class {
    func present(_ viewController: UIViewController, for view: ContactUsBannerView)
}

class ContactUsBannerView: UIView {
    static let bannerHeight = CGFloat(60)

    private let button = UIButton(type: .system)
    private let imageView = UIImageView()
    private let label = UILabel()

    weak var delegate: ContactUsBannerViewDelegate?

    private var emailTemplate: String {
        return """
               \n\n\n

               \(R.string.localizable.aHelpContactEmailHelpfulToDevelopers())
               \(R.string.localizable.aHelpContactEmailIosVersion(UIDevice.current.systemVersion))
               \(R.string.localizable.aHelpContactEmailDeviceModel("\(UIDevice.type.rawValue) \(UIDevice.type == .unrecognized ? " - \(UIDevice.current.model)" : "")"))
               \(R.string.localizable.aHelpContactEmailAppVersion("\(Bundle.main.fullVersion). \(TokenScript.supportedTokenScriptNamespaceVersion)"))
               \(R.string.localizable.aHelpContactEmailLocale(Locale.preferredLanguages.first ?? ""))
               """
    }

    override init(frame: CGRect) {
        super.init(frame: CGRect())

        let stackView = [imageView, label].asStackView(spacing: 14, contentHuggingPriority: .required)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addSubview(button)

        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
            stackView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),

            button.anchorsConstraint(to: self),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = UIColor(red: 249, green: 208, blue: 33)

        imageView.image = R.image.onboarding_contact()

        label.textColor = Colors.appText
        label.font = Fonts.light(size: 18)
        label.text = R.string.localizable.aHelpContactFooterButtonTitle()
    }

    @objc func tapped() {
        sendUsEmail()
    }

    func sendUsEmail() {
        let composerController = MFMailComposeViewController()
        composerController.mailComposeDelegate = self
        composerController.setToRecipients([Constants.supportEmail])
        composerController.setSubject(R.string.localizable.aHelpContactEmailSubject())
        composerController.setMessageBody(emailTemplate, isHTML: false)

        if MFMailComposeViewController.canSendMail() {
            delegate?.present(composerController, for: self)
        }
    }
}

extension ContactUsBannerView: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
