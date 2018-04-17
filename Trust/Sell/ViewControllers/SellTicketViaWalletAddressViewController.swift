// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import TrustKeystore

protocol SellTicketViaWalletAddressViewControllerDelegate: class {
    func didChooseSell(to walletAddress: String, viewController: SellTicketViaWalletAddressViewController)
}

class SellTicketViaWalletAddressViewController: UIViewController {
    //roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
    let roundedBackground = UIView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let textField = UITextField()
    let ticketView = TicketRowView()
    let actionButton = UIButton(type: .system)
    var paymentFlow: PaymentFlow
    weak var delegate: SellTicketViaWalletAddressViewControllerDelegate?
    let ticketHolder: TicketHolder
    var linkExpiryDate: Date
    var ethCost: String
    var dollarCost: String

    init(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, paymentFlow: PaymentFlow) {
        self.ticketHolder = ticketHolder
        self.linkExpiryDate = linkExpiryDate
        self.ethCost = ethCost
        self.dollarCost = dollarCost
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.cornerRadius = 20
        view.addSubview(roundedBackground)

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.returnKeyType = .done

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(sell), for: .touchUpInside)
        roundedBackground.addSubview(actionButton)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ticketView)

        let stackView = UIStackView(arrangedSubviews: [
            .spacer(height: 7),
            titleLabel,
            .spacer(height: 20),
            subtitleLabel,
            .spacer(height: 10),
            textField,
            .spacer(height: 40),
            ticketView,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.alignment = .center
        roundedBackground.addSubview(stackView)

        let marginToHideBottomRoundedCorners = CGFloat(30)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            textField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),
            textField.heightAnchor.constraint(equalToConstant: 50),

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor, constant: 16),

            actionButton.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 60),
            actionButton.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor, constant: -marginToHideBottomRoundedCorners),

            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SellTicketViaWalletAddressViewControllerViewModel) {
        roundedBackground.backgroundColor = viewModel.contentsBackgroundColor
        roundedBackground.layer.cornerRadius = 20

        titleLabel.numberOfLines = 0
        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.textAlignment = .center
        titleLabel.text = viewModel.titleLabelText

        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        subtitleLabel.textAlignment = .center
        subtitleLabel.text = viewModel.subtitleLabelText

        textField.textColor = viewModel.textFieldTextColor
        textField.font = viewModel.textFieldFont
        textField.layer.borderColor = viewModel.textFieldBorderColor.cgColor
        textField.layer.borderWidth = viewModel.textFieldBorderWidth
        textField.leftView = .spacerWidth(viewModel.textFieldHorizontalPadding)
        textField.leftViewMode = .always
        textField.rightView = .spacerWidth(viewModel.textFieldHorizontalPadding)
        textField.rightViewMode = .always

        ticketView.configure(viewModel: .init())

        ticketView.stateLabel.isHidden = true

        ticketView.ticketCountLabel.text = viewModel.ticketCount

        ticketView.titleLabel.text = viewModel.title

        ticketView.venueLabel.text = viewModel.venue

        ticketView.dateLabel.text = viewModel.date

        ticketView.seatRangeLabel.text = viewModel.seatRange

        ticketView.zoneNameLabel.text = viewModel.zoneName

        actionButton.setTitle(viewModel.actionButtonTitle, for: .normal)
        actionButton.setTitleColor(viewModel.actionButtonTitleColor, for: .normal)
        actionButton.setBackgroundColor(viewModel.actionButtonBackgroundColor, forState: .normal)
        actionButton.titleLabel?.font = viewModel.actionButtonTitleFont
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        actionButton.layer.cornerRadius = actionButton.frame.size.height / 2
        textField.layer.cornerRadius = textField.frame.size.height / 2
    }

    @objc func sell() {
        if let address = textField.text, !address.isEmpty {
            guard let _ = Address(string: address) else {
                displayError(error: Errors.invalidAddress)
                return
            }

            delegate?.didChooseSell(to: address, viewController: self)
        }
    }
}

extension SellTicketViaWalletAddressViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
