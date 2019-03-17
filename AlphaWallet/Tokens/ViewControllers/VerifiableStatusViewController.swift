// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

@objc protocol VerifiableStatusViewController {
    @objc func showContractWebPage()
    @objc func showInfo()
}

extension VerifiableStatusViewController where Self: UIViewController {
    func updateNavigationRightBarButtons(withVerificationType verificationType: TokenScriptVerificationType, hasShowInfoButton: Bool = true) {
        let verificationStatusBar = UIBarButtonItem(customView: createVerificationStatusButton(withVerificationType: verificationType))
        switch verificationType {
        case .verified:
            var showInfoButton = hasShowInfoButton
            //TODO ugly
            if let tokenVerifiableVC = self as? TokenVerifiableStatusViewController {
                showInfoButton = tokenVerifiableVC.contract == Constants.ticketContractAddress || tokenVerifiableVC.contract == Constants.ticketContractAddressRopsten
            }
            if showInfoButton {
                let infoButton = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))
                navigationItem.rightBarButtonItems = [infoButton, verificationStatusBar]
            } else {
                navigationItem.rightBarButtonItems = [verificationStatusBar]
            }
        case .unverified, .notCanonicalized:
            navigationItem.rightBarButtonItems = [verificationStatusBar]
        }
    }

    private func createVerificationStatusButton(withVerificationType verificationType: TokenScriptVerificationType) -> UIButton {
        let title: String
        let image: UIImage?
        let tintColor: UIColor
        switch verificationType {
        case .verified:
            title = R.string.localizable.aWalletTokenVerifiedContract()
            image = R.image.verified()
            tintColor = Colors.appGreenContrastBackground
        case .unverified:
            title = R.string.localizable.aWalletTokenUnverifiedContract()
            image = R.image.unverified()
            tintColor = Colors.appRed
        case .notCanonicalized:
            title = R.string.localizable.aWalletTokenDebugContract()
            image = R.image.unverified()
            tintColor = Colors.appRed
        }
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.imageView?.tintColor = tintColor
        button.titleLabel?.font = Fonts.regular(size: 11)
        button.setTitleColor(tintColor, for: .normal)
        //TODO hardcoded margins don't work well across languages, e.g. for Chinese
        button.imageEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 12)
        button.titleEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: -12)
        button.addTarget(self, action: #selector(showContractWebPage), for: .touchUpInside)
        return button
    }
}

protocol TokenVerifiableStatusViewController: VerifiableStatusViewController {
    var contract: String { get }
    var server: RPCServer { get }
    var assetDefinitionStore: AssetDefinitionStore { get }
}

extension TokenVerifiableStatusViewController {
    var verificationType: TokenScriptVerificationType {
        return XMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore).verificationType(for: server)
    }
}

protocol OptionalTokenVerifiableStatusViewController: VerifiableStatusViewController {
    var contract: String? { get }
    var server: RPCServer { get }
    var assetDefinitionStore: AssetDefinitionStore { get }
}

extension OptionalTokenVerifiableStatusViewController {
    var verificationType: TokenScriptVerificationType {
        guard let contract = contract else { return .unverified }
        return XMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore).verificationType(for: server)
    }
}
