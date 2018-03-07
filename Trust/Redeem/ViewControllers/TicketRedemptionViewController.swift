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

    override
    func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        timer = Timer.scheduledTimer(timeInterval: 5,
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
        imageView.image = redeem.redeemMessage(ticketIndices: getIndices()).toQRCode()
    }

    private func getIndices() -> [UInt16] {
        let tickets = viewModel.ticketHolder.tickets
        return tickets.map { $0.index }
    }
}
