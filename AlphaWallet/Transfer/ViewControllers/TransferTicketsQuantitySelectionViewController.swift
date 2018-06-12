// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TransferTicketsQuantitySelectionViewControllerDelegate: class {
    func didSelectQuantity(token: TokenObject, ticketHolder: TicketHolder, in viewController: TransferTicketsQuantitySelectionViewController)
    func didPressViewInfo(in viewController: TransferTicketsQuantitySelectionViewController)
    func didPressViewContractWebPage(in viewController: TransferTicketsQuantitySelectionViewController)
}

class TransferTicketsQuantitySelectionViewController: UIViewController {

    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
	let subtitleLabel = UILabel()
    var quantityStepper = NumberStepper()
    let ticketView = TicketRowView()
    let nextButton = UIButton(type: .system)
    var viewModel: TransferTicketsQuantitySelectionViewModel!
    var paymentFlow: PaymentFlow
    weak var delegate: TransferTicketsQuantitySelectionViewControllerDelegate?

    init(paymentFlow: PaymentFlow) {
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo)),
            UIBarButtonItem(image: R.image.settings_lock(), style: .plain, target: self, action: #selector(showContractWebPage))
        ]

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ticketView)

        quantityStepper.translatesAutoresizingMaskIntoConstraints = false
        quantityStepper.minimumValue = 1
        quantityStepper.value = 1
        view.addSubview(quantityStepper)

        let stackView = [
            header,
            ticketView,
            .spacer(height: 20),
            subtitleLabel,
            .spacer(height: 4),
            quantityStepper,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let buttonsStackView = [nextButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

			quantityStepper.heightAnchor.constraint(equalToConstant: 50),

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func nextButtonTapped() {
        if quantityStepper.value == 0 {
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTicketTokenTransferSelectTicketQuantityAtLeastOneTitle(),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectQuantity(token: viewModel.token, ticketHolder: getTicketHolderFromQuantity(), in: self)
        }
    }

    @objc func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    @objc func showContractWebPage() {
        delegate?.didPressViewContractWebPage(in: self)
    }

    func configure(viewModel: TransferTicketsQuantitySelectionViewModel) {
        self.viewModel = viewModel
        let contractAddress = XMLHandler().getAddressFromXML(server: Config().server).eip55String
        if viewModel.token.contract != contractAddress {
            navigationItem.rightBarButtonItems = [UIBarButtonItem(image: R.image.settings_lock(), style: .plain, target: self, action: #selector(showContractWebPage))]
        }

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        subtitleLabel.text = viewModel.subtitleText

        ticketView.configure(viewModel: .init(ticketHolder: viewModel.ticketHolder))

        quantityStepper.borderWidth = 1
        quantityStepper.clipsToBounds = true
        quantityStepper.borderColor = viewModel.stepperBorderColor
        quantityStepper.maximumValue = viewModel.maxValue

        ticketView.stateLabel.isHidden = true

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
            status: ticketHolder.status
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        quantityStepper.layer.cornerRadius = quantityStepper.frame.size.height / 2
    }
}
