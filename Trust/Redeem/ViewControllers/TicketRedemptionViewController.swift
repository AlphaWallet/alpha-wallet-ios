//
//  TicketRedemptionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class TicketRedemptionViewController: UIViewController {

    @IBOutlet weak var ticketView: TicketView!
    @IBOutlet weak var imageView: UIImageView!
    var viewModel: TicketRedemptionViewModel!
    let redeem = CreateRedeem()
    var timer: Timer!
    var session: WalletSession!
    let redeemListener = RedeemEventListener()

    override
    func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        timer = Timer.scheduledTimer(timeInterval: 30,
                                     target: self,
                                     selector: #selector(configureUI),
                                     userInfo: nil,
                                     repeats: true)
        redeemListener.shouldListen = true
        redeemListener.start(completion: {
            self.redeemListener.stop()
            self.showSuccessMessage()
        })
    }

    override
    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = viewModel.title
    }

    override
    func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        invalidateTimer()
        redeemListener.stop()
    }

    @objc
    private func configureUI() {
        let redeemData = redeem.redeemMessage(ticketIndices: viewModel.ticketHolder.ticketIndices)
        switch session.account.type {
        case .real(let account):
            let decimalSignature = SignatureHelper.signatureAsDecimal(for: redeemData.message, account: account)!
            let qrCodeInfo = redeemData.qrCode + decimalSignature
            imageView.image = qrCodeInfo.toQRCode()
        case .watch: break // TODO: What to do here?
        }
        ticketView.configure(ticketHolder: viewModel.ticketHolder)
    }

    private func showSuccessMessage() {
        invalidateTimer()
        UIAlertController.alert(title: "Congrats",
                                message: "You have successfully redeemed your ticket(s)",
                                alertButtonTitles: ["OK"],
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
    
    deinit {
        print("deinit called")
    }

 }
