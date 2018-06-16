// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

@objc protocol VerifiableStatusViewController {
    @objc func showContractWebPage()
    @objc func showInfo()
}

extension VerifiableStatusViewController where Self: UIViewController {
    func updateNavigationRightBarButtons(isVerified: Bool, hasShowInfoButton: Bool = true) {
        if isVerified {
            let button = UIBarButtonItem(image: R.image.verified(), style: .plain, target: self, action: #selector(showContractWebPage))
            button.tintColor = Colors.appGreenContrastBackground
            if hasShowInfoButton {
                navigationItem.rightBarButtonItems = [
                    UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo)),
                    button
                ]
            } else {
                navigationItem.rightBarButtonItems = [button]
            }
        } else {
            let button = UIBarButtonItem(image: R.image.unverified(), style: .plain, target: self, action: #selector(showContractWebPage))
            button.tintColor = Colors.appRed
            navigationItem.rightBarButtonItems = [button]
        }
    }
}
