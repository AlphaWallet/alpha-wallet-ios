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
    func didPressViewRedemptionInfo(in viewController: QuantitySelectionViewController)
}

class QuantitySelectionViewController: UIViewController {

    //roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
    let roundedBackground = UIView()
    let header = TicketsViewControllerTitleHeader()
	let subtitleLabel = UILabel()
    var quantityStepper = NumberStepper()
    let ticketView = TicketRowView()
    let nextButton = UIButton(type: .system)
    var viewModel: QuantitySelectionViewModel!
    weak var delegate: QuantitySelectionViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.backgroundColor = Colors.appWhite
        roundedBackground.cornerRadius = 20
        view.addSubview(roundedBackground)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle(R.string.localizable.aWalletTicketTokenRedeemButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ticketView)

        quantityStepper.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(quantityStepper)

        let stackView = UIStackView(arrangedSubviews: [
            header,
            subtitleLabel,
            .spacer(height: 4),
            quantityStepper,
            .spacer(height: 50),
            ticketView,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill
		stackView.alignment = .center
        roundedBackground.addSubview(stackView)

        let buttonsStackView = UIStackView(arrangedSubviews: [nextButton])
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 0
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.setContentHuggingPriority(.required, for: .horizontal)
        roundedBackground.addSubview(buttonsStackView)

        let marginToHideBottomRoundedCorners = CGFloat(30)
        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

			quantityStepper.heightAnchor.constraint(equalToConstant: 50),

            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
//            stackView.bottomAnchor.constraint(lessThanOrEqualTo: buttonsStackView.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: 60),
            buttonsStackView.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor, constant: -marginToHideBottomRoundedCorners),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    @objc func showInfo() {
        delegate?.didPressViewRedemptionInfo(in: self)
    }

    func configure(viewModel: QuantitySelectionViewModel) {
        self.viewModel = viewModel

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        subtitleLabel.text = viewModel.subtitleText

        ticketView.configure(viewModel: .init())

        quantityStepper.borderWidth = 2
        quantityStepper.clipsToBounds = true
        quantityStepper.borderColor = viewModel.stepperBorderColor
        quantityStepper.maximumValue = viewModel.maxValue

        ticketView.stateLabel.isHidden = true

        ticketView.ticketCountLabel.text = viewModel.ticketCount

        ticketView.titleLabel.text = viewModel.title

        ticketView.venueLabel.text = viewModel.venue

        ticketView.dateLabel.text = viewModel.date

        ticketView.seatRangeLabel.text = viewModel.seatRange

        ticketView.zoneNameLabel.text = viewModel.zoneName

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        quantityStepper.layer.cornerRadius = quantityStepper.frame.size.height / 2
    }

    deinit {
        print("deinit quantity view controller")
    }

}
