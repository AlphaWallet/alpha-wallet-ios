//
//  TokenRedemptionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class TokenRedemptionViewController: UIViewController, TokenVerifiableStatusViewController {

    let config: Config
    var contract: String {
        return token.contract
    }
    var viewModel: TokenRedemptionViewModel
    var titleLabel = UILabel()
    let imageView =  UIImageView()
    let TokenView: TokenRowView & UIView
    var timer: Timer!
    var session: WalletSession
    private let token: TokenObject
    let redeemListener = RedeemEventListener()

    init(config: Config, session: WalletSession, token: TokenObject, viewModel: TokenRedemptionViewModel) {
        self.config = config
		self.session = session
        self.token = token
        self.viewModel = viewModel

        let tokenType = CryptoKittyHandling(address: token.address)
        switch tokenType {
        case .cryptoKitty:
            TokenView = TokenListFormatRowView()
        case .otherNonFungibleToken:
            TokenView = TokenRowView()
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        imageView.translatesAutoresizingMaskIntoConstraints = false

        let imageHolder = UIView()
        imageHolder.translatesAutoresizingMaskIntoConstraints = false
        imageHolder.backgroundColor = Colors.appWhite
        imageHolder.cornerRadius = 20
        imageHolder.addSubview(imageView)

        TokenView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            titleLabel,
            .spacer(height: 10),
            imageHolder,
            .spacer(height: 4),
            TokenView,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            imageView.leadingAnchor.constraint(equalTo: imageHolder.leadingAnchor, constant: 70),
            imageView.trailingAnchor.constraint(equalTo: imageHolder.trailingAnchor, constant: -70),
            imageView.topAnchor.constraint(equalTo: imageHolder.topAnchor, constant: 70),
            imageView.bottomAnchor.constraint(equalTo: imageHolder.bottomAnchor, constant: -70),

            imageHolder.leadingAnchor.constraint(equalTo: TokenView.background.leadingAnchor),
            imageHolder.trailingAnchor.constraint(equalTo: TokenView.background.trailingAnchor),
			imageHolder.widthAnchor.constraint(equalTo: imageHolder.heightAnchor),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override
    func viewDidLoad() {
        super.viewDidLoad()
        timer = Timer.scheduledTimer(timeInterval: 30,
                                     target: self,
                                     selector: #selector(configureUI),
                                     userInfo: nil,
                                     repeats: true)
        redeemListener.shouldListen = true
        redeemListener.start(for: session.account.address,
                             completion: {
            self.redeemListener.stop()
            self.showSuccessMessage()
        })
    }

    override
    func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        invalidateTimer()
        redeemListener.stop()
    }

    @objc
    private func configureUI() {
        let redeem = CreateRedeem(config: session.config, token: token)
        let redeemData = redeem.redeemMessage(TokenIndices: viewModel.TokenHolder.indices)
        switch session.account.type {
        case .real(let account):
            let decimalSignature = SignatureHelper.signatureAsDecimal(for: redeemData.message, account: account)!
            let qrCodeInfo = redeemData.qrCode + decimalSignature
            imageView.image = qrCodeInfo.toQRCode()
        case .watch: break
        }
    }

    func showInfo() {
        let controller = TokenRedemptionInfoViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    func showContractWebPage() {
        let url = session.config.server.etherscanContractDetailsWebPageURL(for: viewModel.token.contract)
        openURL(url)
    }

    private func showSuccessMessage() {
        invalidateTimer()

        UIAlertController.alert(title: R.string.localizable.aWalletTokenTokenRedeemSuccessfulTitle(),
                                message: R.string.localizable.aWalletTokenTokenRedeemSuccessfulDescription(),
                                alertButtonTitles: [R.string.localizable.oK()],
                                alertButtonStyles: [.cancel],
                                viewController: self,
                                completion: { _ in
                                    // TODO: let Token coordinator handle this as we need to refresh the Token list as well
                                    self.dismiss(animated: true, completion: nil)
                                })

    }

    private func invalidateTimer() {
        if timer.isValid {
            timer.invalidate()
        }
    }
    
    func configure(viewModel newViewModel: TokenRedemptionViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(isVerified: isContractVerified)

        view.backgroundColor = viewModel.backgroundColor

        titleLabel.textAlignment = .center
        titleLabel.textColor = viewModel.headerColor
        titleLabel.font = viewModel.headerFont
        titleLabel.numberOfLines = 0
        titleLabel.text = viewModel.headerTitle

        configureUI()

        TokenView.configure(tokenHolder: viewModel.TokenHolder)

        TokenView.stateLabel.isHidden = true
    }
 }
