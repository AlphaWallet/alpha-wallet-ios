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

        backgroundColor = .init(red: 0, green: 0, blue: 0, alpha: 0.3)

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
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            dialog.rightAnchor.constraint(equalTo: rightAnchor, constant: -20),
            dialog.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -120),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func clipBottomRight() {
        //TODO support clipping for iPad too
        if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone {
            let clipDimension = CGFloat(180)
            let clipPath = UIBezierPath(ovalIn: CGRect(x: UIScreen.main.bounds.size.width - clipDimension / 2 - 20, y: UIScreen.main.bounds.size.height - clipDimension / 2 - 20, width: clipDimension, height: clipDimension))
            let maskPath = UIBezierPath(rect: UIScreen.main.bounds)
            maskPath.append(clipPath.reversing())
            let mask = CAShapeLayer()
            mask.backgroundColor = UIColor.red.cgColor
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
        UIApplication.shared.keyWindow?.addSubview(self)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 7, options: .curveEaseInOut, animations: {
            self.dialog.transform = .identity
        })

        //TODO sound too
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        feedbackGenerator.notificationOccurred(.success)
    }
}

extension WhereIsWalletAddressFoundOverlayView: DialogDelegate {
    fileprivate func tappedContinue(inDialog dialog: Dialog) {
        hide()
    }
}

fileprivate protocol DialogDelegate: class {
    func tappedContinue(inDialog dialog: Dialog)
}

fileprivate class Dialog: UIView {
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)

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
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            widthAnchor.constraint(equalToConstant: 300),
            heightAnchor.constraint(equalToConstant: 250),

            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 30),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = Colors.appWhite

        titleLabel.font = Fonts.regular(size: 24)
        titleLabel.textColor = .init(red: 33, green: 33, blue: 33)
        titleLabel.textAlignment = .center
        titleLabel.text = R.string.localizable.onboardingNewWalletFindAddressTitle()

        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = Fonts.regular(size: 18)
        descriptionLabel.textColor = .init(red: 102, green: 102, blue: 102)
        descriptionLabel.textAlignment = .center
        descriptionLabel.text = R.string.localizable.onboardingNewWalletFindAddressDescription()

        buttonsBar.configure()
        let continueButton = buttonsBar.buttons[0]
        continueButton.setTitle("Continue".localizedUppercase, for: .normal)
        continueButton.addTarget(self, action: #selector(hide), for: .touchUpInside)
    }

    @objc private func hide() {
        delegate?.tappedContinue(inDialog: self)
    }
}
