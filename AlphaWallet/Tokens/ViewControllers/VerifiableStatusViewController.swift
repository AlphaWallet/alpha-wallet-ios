// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

@objc protocol VerifiableStatusViewController {
    @objc func showContractWebPage()
    @objc func showInfo()
}

extension VerifiableStatusViewController where Self: UIViewController {
    func updateNavigationRightBarButtons(isVerified: Bool, hasShowInfoButton: Bool = true) {
        let verifiedStatusButton = UIBarButtonItem(customView: createVerifiedStatusButton(isVerified: isVerified))
        if isVerified {
            if hasShowInfoButton {
                let infoButton = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))
                navigationItem.rightBarButtonItems = [
                    infoButton,
                    verifiedStatusButton
                ]
            } else {
                navigationItem.rightBarButtonItems = [verifiedStatusButton]
            }
        } else {
            navigationItem.rightBarButtonItems = [verifiedStatusButton]
        }
    }

    private func createVerifiedStatusButton(isVerified: Bool) -> UIButton {
        let title: String
        let image: UIImage?
        let tintColor: UIColor
        if isVerified {
            title = R.string.localizable.aWalletTicketTokenVerifiedContract()
            image = R.image.verified()
            tintColor = Colors.appGreenContrastBackground
        } else {
            title = R.string.localizable.aWalletTicketTokenUnverifiedContract()
            image = R.image.unverified()
            tintColor = Colors.appRed
        }
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.imageView?.tintColor = tintColor
        button.titleLabel?.font = Fonts.regular(size: 11)
        button.setTitleColor(tintColor, for: .normal)
        button.addTarget(self, action: #selector(showContractWebPage), for: .touchUpInside)
        return button
    }
}
