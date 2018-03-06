//
//  RedeemTicketsViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/4/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

protocol RedeemTicketsViewControllerDelegate: class {
    func didSelectTicketHolder(ticketHolder: TicketHolder, in viewController: UIViewController)
}

class RedeemTicketsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    var viewModel: RedeemTicketsViewModel!
    weak var delegate: RedeemTicketsViewControllerDelegate?

    override
    func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Next", value: "Next", comment: ""),
            style: .done,
            target: self,
            action: #selector(nextButtonTapped)
        )
    }

    override
    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = viewModel.title
    }

    private func resetSelection(for ticketHolder: TicketHolder) {
        let status = ticketHolder.status
        viewModel.ticketHolders?.forEach { $0.status = .available }
        ticketHolder.status = (status == .available) ? .redeemed : .available
        tableView.reloadData()
    }

    @objc
    func nextButtonTapped() {
        let selectedTicketHolders = viewModel.ticketHolders?.filter { $0.status == .redeemed }
        if selectedTicketHolders!.isEmpty {
            UIAlertController.alert(title: "",
                                    message: "Please select a ticket to redeem",
                                    alertButtonTitles: ["OK"],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            self.delegate?.didSelectTicketHolder(ticketHolder: selectedTicketHolders!.first!, in: self)
        }
    }
}

extension RedeemTicketsViewController: UITableViewDelegate, UITableViewDataSource {
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
            resetSelection(for: ticketHolder)
        }
    }
}
