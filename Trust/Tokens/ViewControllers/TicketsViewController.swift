//
//  TicketsViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import Result
import TrustKeystore

protocol TicketsViewControllerDelegate: class {
    func didPressRedeem(token: TokenObject, in viewController: TicketsViewController)
    func didPressSell(for type: PaymentFlow, in viewController: TicketsViewController)
    func didPressTransfer(for type: PaymentFlow, ticketHolders: [TicketHolder], in viewController: TicketsViewController)
    func didCancel(in viewController: TicketsViewController)
    func didPressViewRedemptionInfo(in viewController: TicketsViewController)
}

class TicketsViewController: UIViewController {

    var tokenObject: TokenObject?
    //TODO forced unwraps aren't good
    var viewModel: TicketsViewModel!
    var tokensStorage: TokensDataStore!
    var account: Wallet!
    var session: WalletSession!
    weak var delegate: TicketsViewControllerDelegate?
    let header = TicketsViewControllerHeader()
    //roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
    let roundedBackground = UIView()
    let tableView = UITableView(frame: .zero, style: .plain)

    let redeemButton = UIButton(type: .system)
    let sellButton = UIButton(type: .system)
    let transferButton = UIButton(type: .system)

    init() {
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

        view.backgroundColor = Colors.appBackground
		
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.backgroundColor = Colors.appWhite
        roundedBackground.cornerRadius = 20
        view.addSubview(roundedBackground)

        tableView.register(TicketTableViewCellWithoutCheckbox.self, forCellReuseIdentifier: TicketTableViewCellWithoutCheckbox.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.tableHeaderView = header
        roundedBackground.addSubview(tableView)

        redeemButton.setTitle(R.string.localizable.aWalletTicketTokenRedeemButtonTitle(), for: .normal)
        redeemButton.addTarget(self, action: #selector(redeem), for: .touchUpInside)

        sellButton.setTitle(R.string.localizable.aWalletTicketTokenSellButtonTitle(), for: .normal)
        sellButton.addTarget(self, action: #selector(sell), for: .touchUpInside)

        transferButton.setTitle(R.string.localizable.aWalletTicketTokenTransferButtonTitle(), for: .normal)
        transferButton.addTarget(self, action: #selector(transfer), for: .touchUpInside)

        let buttonsStackView = UIStackView(arrangedSubviews: [redeemButton, sellButton, transferButton])
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 0
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        let marginToHideBottomRoundedCorners = CGFloat(30)
        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        let separator0 = UIView()
        separator0.translatesAutoresizingMaskIntoConstraints = false
        separator0.backgroundColor = Colors.appLightButtonSeparator
        footerBar.addSubview(separator0)

        let separator1 = UIView()
        separator1.translatesAutoresizingMaskIntoConstraints = false
        separator1.backgroundColor = separator0.backgroundColor
        footerBar.addSubview(separator1)

		let separatorThickness = CGFloat(1)
        NSLayoutConstraint.activate([
            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),

            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            separator0.leadingAnchor.constraint(equalTo: redeemButton.trailingAnchor, constant: -separatorThickness / 2),
            separator0.trailingAnchor.constraint(equalTo: sellButton.leadingAnchor, constant: separatorThickness / 2),
			separator0.topAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: 8),
            separator0.bottomAnchor.constraint(equalTo: buttonsStackView.bottomAnchor, constant: -8),

            separator1.leadingAnchor.constraint(equalTo: sellButton.trailingAnchor, constant: -0.5),
            separator1.trailingAnchor.constraint(equalTo: transferButton.leadingAnchor, constant: 0.5),
            separator1.topAnchor.constraint(equalTo: separator0.topAnchor),
            separator1.bottomAnchor.constraint(equalTo: separator0.bottomAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TicketsViewModel) {
        self.viewModel = viewModel
        tableView.dataSource = self

        if let tokenObject = tokenObject {
            header.configure(viewModel: .init(tokenObject: tokenObject))
            tableView.tableHeaderView = header
        }

        redeemButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		redeemButton.backgroundColor = viewModel.buttonBackgroundColor
        redeemButton.titleLabel?.font = viewModel.buttonFont

        sellButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        sellButton.backgroundColor = viewModel.buttonBackgroundColor
        sellButton.titleLabel?.font = viewModel.buttonFont

        transferButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        transferButton.backgroundColor = viewModel.buttonBackgroundColor
        transferButton.titleLabel?.font = viewModel.buttonFont
    }

    override
    func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(didTapCancelButton))
    }

    @IBAction
    func didTapCancelButton(_ sender: UIBarButtonItem) {
        delegate?.didCancel(in: self)
    }

    @objc func redeem() {
        delegate?.didPressRedeem(token: viewModel.token,
                                 in: self)
    }

    @objc func sell() {
        delegate?.didPressSell(for: .send(type: .stormBird(viewModel.token)), in: self)
    }

    @objc func transfer() {
        delegate?.didPressTransfer(for: .send(type: .stormBird(viewModel.token)),
                                   ticketHolders: viewModel.ticketHolders!,
                                   in: self)
    }

    @objc func showInfo() {
		delegate?.didPressViewRedemptionInfo(in: self)
    }

    private func animateRowHeightChanges(for indexPaths: [IndexPath], in tableview: UITableView) {
        tableView.reloadRows(at: indexPaths, with: .automatic)
        tableView.beginUpdates()
        tableView.endUpdates()
    }
}

extension TicketsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TicketTableViewCellWithoutCheckbox.identifier, for: indexPath) as! TicketTableViewCellWithoutCheckbox
        let ticketHolder = viewModel.item(for: indexPath)
		cell.configure(viewModel: .init(ticketHolder: ticketHolder))
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let ticketHolder = viewModel.item(for: indexPath)
        let cellViewModel = TicketTableViewCellViewModel(ticketHolder: ticketHolder)
        return cellViewModel.cellHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let ticketHolder = viewModel.item(for: indexPath)
        let changedIndexPaths = viewModel.toggleDetailsVisible(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }
}
