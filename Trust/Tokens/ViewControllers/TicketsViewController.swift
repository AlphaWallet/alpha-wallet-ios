//
//  TicketsViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import StatefulViewController
import Result
import TrustKeystore

protocol TicketsViewControllerDelegate: class {
    func didPressRedeem(token: TokenObject, in viewController: UIViewController)
    func didPressSell(token: TokenObject, in viewController: UIViewController)
    func didPressTransfer(for type: PaymentFlow, ticketHolders: [TicketHolder], in viewController: UIViewController)
    func didCancel(in viewController: UIViewController)
}

class TicketsViewController: UIViewController {

    var viewModel: TicketsViewModel!
    var tokensStorage: TokensDataStore!
    var account: Wallet!
    var session: WalletSession!
    weak var delegate: TicketsViewControllerDelegate?

    override
    func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(didTapCancelButton))
    }

    override
    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.applyTintAdjustment()
        title = viewModel.title
    }

    @IBAction
    func didTapCancelButton(_ sender: UIBarButtonItem) {
        delegate?.didCancel(in: self)
    }

    @IBAction
    func didPressRedeem(_ sender: UIButton) {
        delegate?.didPressRedeem(token: viewModel.token,
                                 in: self)
    }

    @IBAction
    func didPressSell(_ sender: UIButton) {
        delegate?.didPressSell(token: viewModel.token, in: self)
    }

    @IBAction
    func didPressTransfer(_ sender: UIButton) {
        delegate?.didPressTransfer(for: .send(type: .stormBird(viewModel.token)),
                                   ticketHolders: viewModel.ticketHolders!,
                                   in: self)
    }
}

extension TicketsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return viewModel.cell(for: tableView, indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return viewModel.height(for: indexPath.section)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if viewModel.ticketCellPressed(for: indexPath) {
            let ticketHolder = viewModel.item(for: indexPath)
            delegate?.didPressTransfer(for: .send(type: .stormBird(viewModel.token)),
                                       ticketHolders: [ticketHolder],
                                       in: self)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
