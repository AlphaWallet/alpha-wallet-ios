// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TransferTicketsViewControllerDelegate: class {
    func didSelectTicketHolder(token: TokenObject, ticketHolder: TicketHolder, in viewController: TransferTicketsViewController)
    func didPressViewInfo(in viewController: TransferTicketsViewController)
    func didPressViewContractWebPage(in viewController: TransferTicketsViewController)
}

class TransferTicketsViewController: UIViewController {

    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
    let tableView = UITableView(frame: .zero, style: .plain)
	let nextButton = UIButton(type: .system)
    var viewModel: TransferTicketsViewModel!
    var paymentFlow: PaymentFlow
    weak var delegate: TransferTicketsViewControllerDelegate?

    init(paymentFlow: PaymentFlow) {
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo)),
            UIBarButtonItem(image: R.image.settings_lock(), style: .plain, target: self, action: #selector(showContractWebPage))
        ]

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.register(TicketTableViewCellWithCheckbox.self, forCellReuseIdentifier: TicketTableViewCellWithCheckbox.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.tableHeaderView = header
        roundedBackground.addSubview(tableView)

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        let buttonsStackView = [nextButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

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

    func configure(viewModel: TransferTicketsViewModel) {
        self.viewModel = viewModel
        tableView.dataSource = self
        let contractAddress = XMLHandler().getAddressFromXML(server: RPCServer(chainID: Config().chainID)).eip55String
        if viewModel.token.contract != contractAddress {
            navigationItem.rightBarButtonItems = [UIBarButtonItem(image: R.image.settings_lock(), style: .plain, target: self, action: #selector(showContractWebPage))]
        }

        header.configure(title: viewModel.title)
        tableView.tableHeaderView = header

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    @objc
    func nextButtonTapped() {
        let selectedTicketHolders = viewModel.ticketHolders?.filter { $0.isSelected }
        if selectedTicketHolders!.isEmpty {
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTicketTokenTransferSelectTicketsAtLeastOneTitle(),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            self.delegate?.didSelectTicketHolder(token: viewModel.token, ticketHolder: selectedTicketHolders!.first!, in: self)
        }
    }

    @objc func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    @objc func showContractWebPage() {
        delegate?.didPressViewContractWebPage(in: self)
    }

    private func animateRowHeightChanges(for indexPaths: [IndexPath], in tableview: UITableView) {
        tableView.reloadData()
    }
}

extension TransferTicketsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TicketTableViewCellWithCheckbox.identifier, for: indexPath) as! TicketTableViewCellWithCheckbox
        let ticketHolder = viewModel.item(for: indexPath)
		cell.configure(viewModel: .init(ticketHolder: ticketHolder))
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let ticketHolder = viewModel.item(for: indexPath)
        let cellViewModel = BaseTicketTableViewCellViewModel(ticketHolder: ticketHolder)
        return cellViewModel.cellHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let changedIndexPaths = viewModel.toggleSelection(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }
}
