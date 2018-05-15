//
//  TicketRedemptionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class TicketRedemptionViewController: UIViewController {

    var viewModel: TicketRedemptionViewModel!
    var titleLabel = UILabel()
    let imageView =  UIImageView()
    let ticketView = TicketRowView()
    let redeem = CreateRedeem()
    var timer: Timer!
    var session: WalletSession
    let redeemListener = RedeemEventListener()

    init(session: WalletSession) {
		self.session = session
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        imageView.translatesAutoresizingMaskIntoConstraints = false

        let imageHolder = UIView()
        imageHolder.translatesAutoresizingMaskIntoConstraints = false
        imageHolder.backgroundColor = Colors.appWhite
        imageHolder.cornerRadius = 20
        imageHolder.addSubview(imageView)

        ticketView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            titleLabel,
            .spacer(height: 10),
            imageHolder,
            .spacer(height: 4),
            ticketView,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        let xMargin  = CGFloat(16)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            imageView.leadingAnchor.constraint(equalTo: imageHolder.leadingAnchor, constant: 70),
            imageView.trailingAnchor.constraint(equalTo: imageHolder.trailingAnchor, constant: -70),
            imageView.topAnchor.constraint(equalTo: imageHolder.topAnchor, constant: 70),
            imageView.bottomAnchor.constraint(equalTo: imageHolder.bottomAnchor, constant: -70),

            imageHolder.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            imageHolder.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),
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
        let redeemData = redeem.redeemMessage(ticketIndices: viewModel.ticketHolder.indices)
        switch session.account.type {
        case .real(let account):
            let decimalSignature = SignatureHelper.signatureAsDecimal(for: redeemData.message, account: account)!
            let qrCodeInfo = redeemData.qrCode + decimalSignature
            imageView.image = qrCodeInfo.toQRCode()
        case .watch: break // TODO: What to do here?
        }
    }

    @objc func showInfo() {
        let controller = TicketRedemptionInfoViewController()
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showSuccessMessage() {
        invalidateTimer()

        UIAlertController.alert(title: R.string.localizable.aWalletTicketTokenRedeemSuccessfulTitle(),
                                message: R.string.localizable.aWalletTicketTokenRedeemSuccessfulDescription(),
                                alertButtonTitles: [R.string.localizable.oK()],
                                alertButtonStyles: [.cancel],
                                viewController: self,
                                completion: { _ in
                                    // TODO: let ticket coordinator handle this as we need to refresh the ticket list as well
                                    self.dismiss(animated: true, completion: nil)
                                })

    }

    private func invalidateTimer() {
        if timer.isValid {
            timer.invalidate()
        }
    }
    
    func configure(viewModel: TicketRedemptionViewModel) {
        self.viewModel = viewModel

        view.backgroundColor = viewModel.backgroundColor

        titleLabel.textAlignment = .center
        titleLabel.textColor = viewModel.headerColor
        titleLabel.font = viewModel.headerFont
        titleLabel.numberOfLines = 0
        titleLabel.text = viewModel.headerTitle

        configureUI()

        ticketView.configure(viewModel: .init())

        ticketView.stateLabel.isHidden = true

        ticketView.ticketCountLabel.text = viewModel.ticketCount

        ticketView.titleLabel.text = viewModel.title

        ticketView.venueLabel.text = viewModel.venue

        ticketView.dateLabel.text = viewModel.date

        ticketView.seatRangeLabel.text = viewModel.seatRange

        ticketView.cityLabel.text = viewModel.city

        ticketView.categoryLabel.text = viewModel.category

        ticketView.teamsLabel.text = viewModel.teams

        ticketView.matchLabel.text = viewModel.match
    }
 }
