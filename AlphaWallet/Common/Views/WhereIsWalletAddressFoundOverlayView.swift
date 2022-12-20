// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

class WhereIsWalletAddressFoundOverlayView: UIView {
    static func show() {
        let view = WhereIsWalletAddressFoundOverlayView(frame: UIScreen.main.bounds)
        view.show()
    }

    private let dialog = Dialog()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = Configuration.Color.Semantic.overlayBackground

        let blurEffect = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        blurView.alpha = 0.3

        clipBottomRight()

        dialog.delegate = self
        dialog.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dialog)

        NSLayoutConstraint.activate([
            blurView.anchorsConstraint(to: self),

            dialog.rightAnchor.constraint(equalTo: rightAnchor, constant: -20),
            dialog.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -120),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func clipBottomRight() {
        //TODO support clipping for iPad too
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
            let clipDimension = CGFloat(180)
            let clipPath = UIBezierPath(ovalIn: CGRect(x: UIScreen.main.bounds.size.width - clipDimension / 2 - 20, y: UIScreen.main.bounds.size.height - clipDimension / 2 - 20, width: clipDimension, height: clipDimension))
            let maskPath = UIBezierPath(rect: UIScreen.main.bounds)
            maskPath.append(clipPath.reversing())
            let mask = CAShapeLayer()
            mask.backgroundColor = Configuration.Color.Semantic.dangerBackground.cgColor
            mask.path = maskPath.cgPath
            layer.mask = mask
        }
    }

    @objc private func hide() {
        removeFromSuperview()
    }

    func show() {
        dialog.configure()
        dialog.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIApplication.shared.firstKeyWindow?.addSubview(self)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 7, options: .curveEaseInOut, animations: {
            self.dialog.transform = .identity
        })

        UINotificationFeedbackGenerator.show(feedbackType: .success)
    }
}

extension WhereIsWalletAddressFoundOverlayView: DialogDelegate {
    fileprivate func tappedContinue(inDialog dialog: Dialog) {
        hide()
    }
}

private protocol DialogDelegate: AnyObject {
    func tappedContinue(inDialog dialog: Dialog)
}

private class Dialog: UIView {
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))

    weak var delegate: DialogDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        let stackView = [
            titleLabel,
            UIView.spacer(height: 12),
            descriptionLabel,
            UIView.spacer(height: 30),
            buttonsBar
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            buttonsBar.heightAnchor.constraint(equalToConstant: HorizontalButtonsBar.buttonsHeight),

            widthAnchor.constraint(equalToConstant: 300),
            heightAnchor.constraint(equalToConstant: 250),

            stackView.anchorsConstraint(to: self, edgeInsets: .init(top: 30, left: 20, bottom: 30, right: 20)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = Configuration.Color.Semantic.dialogBackground

        titleLabel.font = Fonts.regular(size: 24)
        titleLabel.textColor = Configuration.Color.Semantic.defaultForegroundText
        titleLabel.textAlignment = .center
        titleLabel.text = R.string.localizable.onboardingNewWalletBackupWalletTitle()

        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = Fonts.regular(size: 18)
        descriptionLabel.textColor = Configuration.Color.Semantic.defaultSubtitleText
        descriptionLabel.textAlignment = .center
        descriptionLabel.text = R.string.localizable.onboardingNewWalletBackupWalletDescription()

        buttonsBar.configure()
        let continueButton = buttonsBar.buttons[0]
        continueButton.setTitle(R.string.localizable.continue().localizedUppercase, for: .normal)
        continueButton.addTarget(self, action: #selector(hide), for: .touchUpInside)
    }

    @objc private func hide() {
        delegate?.tappedContinue(inDialog: self)
    }
}

