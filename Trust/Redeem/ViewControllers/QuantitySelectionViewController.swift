//
//  QuantitySelectionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/5/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

protocol QuantitySelectionViewControllerDelegate: class {
    func didSelectQuantity(ticketHolder: TicketHolder, in viewController: UIViewController)
}

class QuantitySelectionViewController: UIViewController {

    @IBOutlet weak var ticketView: TicketView!
    @IBOutlet weak var quantityStepper: NumberStepper!
    var viewModel: QuantitySelectionViewModel!
    weak var delegate: QuantitySelectionViewControllerDelegate?

    override
    func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Next", value: "Next", comment: ""),
            style: .done,
            target: self,
            action: #selector(nextButtonTapped)
        )
        configureUI()
    }

    override
    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = viewModel.title
    }

    @objc
    func nextButtonTapped() {
        if quantityStepper.value == 0 {
            UIAlertController.alert(title: "",
                                    message: "Please select quantity of tickets",
                                    alertButtonTitles: ["OK"],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectQuantity(ticketHolder: getTicketHolderFromQuantity(), in: self)
        }
    }

    private func configureUI() {
        ticketView.configure(ticketHolder: viewModel.ticketHolder)
        quantityStepper.maximumValue = viewModel.maxValue
    }

    private func getTicketHolderFromQuantity() -> TicketHolder {
        let quantity = quantityStepper.value
        let ticketHolder = viewModel.ticketHolder
        let tickets = Array(ticketHolder.tickets[..<quantity])
        return TicketHolder(
            tickets: tickets,
            zone: ticketHolder.zone,
            name: ticketHolder.name,
            venue: ticketHolder.venue,
            date: ticketHolder.date,
            status: ticketHolder.status
        )
    }

    deinit {
        print("deinit quantity view controller")
    }

}
