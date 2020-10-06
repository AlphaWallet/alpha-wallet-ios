// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit

@objc protocol VerifiableStatusViewController: CanOpenURL2 {
    func showContractWebPage()
    func showInfo()
}

extension VerifiableStatusViewController where Self: UIViewController {
    func updateNavigationRightBarButtons(withTokenScriptFileStatus statusPromise: Promise<TokenLevelTokenScriptDisplayStatus>?, hasShowInfoButton: Bool = true) {
        guard let status = statusPromise?.value else {
            let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
            var showInfoButton = hasShowInfoButton
            //TODO ugly. And duplicated below
            if let tokenVerifiableVC = self as? TokenVerifiableStatusViewController {
                showInfoButton = tokenVerifiableVC.contract.isFifaTicketContract
            }
            if showInfoButton {
                let infoButton = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))
                navigationItem.rightBarButtonItems = [infoButton, label]
            } else {
                navigationItem.rightBarButtonItems = [label]
            }
            statusPromise?.done { _ in
                self.updateNavigationRightBarButtons(withTokenScriptFileStatus: statusPromise, hasShowInfoButton: hasShowInfoButton)
            }.cauterize()
            return
        }
        let button = createTokenScriptFileStatusButton(withStatus: status, urlOpener: self)
        let verificationStatusBar = UIBarButtonItem(customView: button)
        switch status {
        case .type0NoTokenScript:
            navigationItem.rightBarButtonItems = []
        case .type1GoodTokenScriptSignatureGoodOrOptional:
            var showInfoButton = hasShowInfoButton
            //TODO ugly
            if let tokenVerifiableVC = self as? TokenVerifiableStatusViewController {
                showInfoButton = tokenVerifiableVC.contract.isFifaTicketContract
            }
            if showInfoButton {
                let infoButton = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))
                navigationItem.rightBarButtonItems = [infoButton, verificationStatusBar]
            } else {
                navigationItem.rightBarButtonItems = [verificationStatusBar]
            }
        case .type2BadTokenScript:
            navigationItem.rightBarButtonItems = [verificationStatusBar]
        }
    }
}

class TokenScriptStatusButton: UIButton {
    var handler: ((CanOpenURL2) -> Void)?
    weak var urlOpener: CanOpenURL2?

    init(urlOpener: CanOpenURL2) {
        self.urlOpener = urlOpener
        super.init(frame: .zero)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func tapped() {
        guard let urlOpener = urlOpener else { return }
        handler?(urlOpener)
    }
}

//TODO move
func createTokenScriptFileStatusButton(withStatus status: TokenLevelTokenScriptDisplayStatus, urlOpener: CanOpenURL2) -> TokenScriptStatusButton {
    let title: String
    let image: UIImage?
    let tintColor: UIColor
    let button = TokenScriptStatusButton(urlOpener: urlOpener)
    button.addTarget(button, action: #selector(TokenScriptStatusButton.tapped), for: .touchUpInside)
    switch status {
    case .type0NoTokenScript:
        return button
    case .type1GoodTokenScriptSignatureGoodOrOptional(let isDebugMode, _, let domain, let rawMessage):
        let message: String
        if let domain = domain {
            button.handler = { urlOpener in
                if !domain.starts(with: "*.") {
                    //http. Some sites don't serve https despite using a TLS cert for signing TokenScript
                    URL(string: "http://\(domain)").flatMap { urlOpener.open(url: $0) }
                }
            }
            message = "\(rawMessage) by \(domain)"
        } else {
            message = rawMessage
        }
        if isDebugMode {
            title = "[DEBUG] \(message)"
        } else {
            title = message
        }
        image = R.image.verified()
        tintColor = Colors.appGreenContrastBackground
    case .type2BadTokenScript(let isDebugMode, let message, let reason):
        switch reason {
        case .some(.oldTokenScriptVersion):
            //TODO have to reload from repo. But we don't have access to an AssetDefinitionStore for now
//            button.handler = { urlOpener in urlOpener.open(url: URL(string: "https://alphawallet.com")!) }
            break
        case .some(.invalidSignature):
            break
        case .some(.conflictWithAnotherFile):
            //TODO open console here
//            button.handler = { urlOpener in  }
            break
        case .none:
            break
        }

        if isDebugMode {
            title = "[DEBUG] \(message)"
        } else {
            title = message
        }
        image = R.image.unverified()
        tintColor = Colors.appRed
    }
    button.setTitle(title, for: .normal)
    button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
    button.imageView?.tintColor = tintColor
    button.titleLabel?.font = Fonts.regular(size: 11)
    button.setTitleColor(tintColor, for: .normal)
    //TODO hardcoded margins don't work well across languages, e.g. for Chinese
    button.imageEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 12)
    button.titleEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: -12)
    return button
}

protocol TokenVerifiableStatusViewController: VerifiableStatusViewController {
    var contract: AlphaWallet.Address { get }
    var server: RPCServer { get }
    var assetDefinitionStore: AssetDefinitionStore { get }
}

extension TokenVerifiableStatusViewController {
    var tokenScriptFileStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        XMLHandler.tokenScriptStatus(forContract: contract, assetDefinitionStore: assetDefinitionStore)
    }
}

protocol OptionalTokenVerifiableStatusViewController: VerifiableStatusViewController {
    var contract: AlphaWallet.Address? { get }
    var server: RPCServer { get }
    var assetDefinitionStore: AssetDefinitionStore { get }
}

extension OptionalTokenVerifiableStatusViewController {
    var tokenScriptFileStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        guard let contract = contract else { return .value(.type0NoTokenScript) }
        return XMLHandler.tokenScriptStatus(forContract: contract, assetDefinitionStore: assetDefinitionStore)
    }
}
