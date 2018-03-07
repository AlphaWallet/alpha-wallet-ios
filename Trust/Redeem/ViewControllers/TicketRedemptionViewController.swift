//
//  TicketRedemptionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit
import BigInt

class TicketRedemptionViewController: UIViewController {

    @IBOutlet weak var ticketView: TicketView!
    @IBOutlet weak var imageView: UIImageView!
    var viewModel: TicketRedemptionViewModel!
    let redeem = CreateRedeem()
    var timer: Timer!
    let keystore = try! EtherKeystore()

    override
    func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        timer = Timer.scheduledTimer(timeInterval: 30,
                                     target: self,
                                     selector: #selector(configureUI),
                                     userInfo: nil,
                                     repeats: true)
    }

    override
    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = viewModel.title
    }

    override
    func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }

    @objc
    private func configureUI() {
        ticketView.configure(ticketHolder: viewModel.ticketHolder)
        let redeemData = redeem.redeemMessage(ticketIndices: viewModel.ticketHolder.ticketIndices)
        //TODO get default account
        let defaultAccount = self.keystore.keyStore.accounts[0]
        let signature = keystore.signMessageData(redeemData.0.data(using: String.Encoding.utf8), for: defaultAccount)
        print("message: " + redeemData.0)
        print(defaultAccount.address)
        let hexSignature = try! OrdersRequest.bytesToHexa(Array(signature.dematerialize()))
        let decimalSignature = BigInt(hexSignature, radix: 16)!.description
        let qrCodeInfo = try! redeemData.1 + decimalSignature
        imageView.image = qrCodeInfo.toQRCode()
    }
}
