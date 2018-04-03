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
    func didPressViewRedemptionInfo(in viewController: UIViewController)
}

class RedeemTicketsViewController: UIViewController {

    //roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
    let roundedBackground = UIView()
    let header = TicketsViewControllerTitleHeader()
    let tableView = UITableView(frame: .zero, style: .plain)
	let nextButton = UIButton(type: .system)
    var viewModel: RedeemTicketsViewModel!
    weak var delegate: RedeemTicketsViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.backgroundColor = Colors.appWhite
        roundedBackground.cornerRadius = 20
        view.addSubview(roundedBackground)

        tableView.register(RedeemTicketTableViewCell.self, forCellReuseIdentifier: RedeemTicketTableViewCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.tableHeaderView = header
        roundedBackground.addSubview(tableView)

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        let buttonsStackView = UIStackView(arrangedSubviews: [nextButton])
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 0
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        roundedBackground.addSubview(buttonsStackView)

        let marginToHideBottomRoundedCorners = CGFloat(30)
        NSLayoutConstraint.activate([
            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),

            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: buttonsStackView.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: 60),
            buttonsStackView.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor, constant: -marginToHideBottomRoundedCorners),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: RedeemTicketsViewModel) {
        self.viewModel = viewModel
        tableView.dataSource = self

        header.configure(title: viewModel.title)
        tableView.tableHeaderView = header

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
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
                                    message: R.string.localizable.aWalletTicketTokenRedeemSelectTicketsAtLeastOneTitle(),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            self.delegate?.didSelectTicketHolder(ticketHolder: selectedTicketHolders!.first!, in: self)
        }
    }

    @objc func showInfo() {
        delegate?.didPressViewRedemptionInfo(in: self)
    }
}

extension RedeemTicketsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RedeemTicketTableViewCell.identifier, for: indexPath) as! RedeemTicketTableViewCell
        let ticketHolder = viewModel.item(for: indexPath)
		cell.configure(viewModel: .init(ticketHolder: ticketHolder))
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let ticketHolder = viewModel.item(for: indexPath)
        let cellViewModel = RedeemTicketTableViewCellViewModel(ticketHolder: ticketHolder)
        return cellViewModel.cellHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let ticketHolder = viewModel.item(for: indexPath)
		resetSelection(for: ticketHolder)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
