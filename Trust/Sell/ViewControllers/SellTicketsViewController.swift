// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol SellTicketsViewControllerDelegate: class {
    func didSelectTicketHolder(ticketHolder: TicketHolder, in viewController: SellTicketsViewController)
    func didPressViewInfo(in viewController: SellTicketsViewController)
}

class SellTicketsViewController: UIViewController {

    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
    let tableView = UITableView(frame: .zero, style: .plain)
	let nextButton = UIButton(type: .system)
    var viewModel: SellTicketsViewModel!
    var paymentFlow: PaymentFlow
    weak var delegate: SellTicketsViewControllerDelegate?

    init(paymentFlow: PaymentFlow) {
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

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

    func configure(viewModel: SellTicketsViewModel) {
        self.viewModel = viewModel
        tableView.dataSource = self

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
                                    message: R.string.localizable.aWalletTicketTokenSellSelectTicketsAtLeastOneTitle(),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            self.delegate?.didSelectTicketHolder(ticketHolder: selectedTicketHolders!.first!, in: self)
        }
    }

    @objc func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    private func animateRowHeightChanges(for indexPaths: [IndexPath], in tableview: UITableView) {
        tableView.reloadData()
    }
}

extension SellTicketsViewController: UITableViewDelegate, UITableViewDataSource {
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
        let ticketHolder = viewModel.item(for: indexPath)
        let changedIndexPaths = viewModel.toggleSelection(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }
}
