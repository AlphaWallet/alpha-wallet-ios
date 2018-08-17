// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol SellTicketsViewControllerDelegate: class {
    func didSelectTicketHolder(ticketHolder: TokenHolder, in viewController: SellTicketsViewController)
    func didPressViewInfo(in viewController: SellTicketsViewController)
    func didPressViewContractWebPage(in viewController: SellTicketsViewController)
    func didTapURL(url: URL, in viewController: SellTicketsViewController)
}

class SellTicketsViewController: UIViewController, TicketVerifiableStatusViewController {

    let config: Config
    var contract: String {
        return viewModel.token.contract
    }
    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
    let tableView = UITableView(frame: .zero, style: .plain)
	let nextButton = UIButton(type: .system)
    var viewModel: SellTicketsViewModel
    var paymentFlow: PaymentFlow
    weak var delegate: SellTicketsViewControllerDelegate?

    init(config: Config, paymentFlow: PaymentFlow, viewModel: SellTicketsViewModel) {
        self.config = config
        self.paymentFlow = paymentFlow
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.register(TicketTableViewCellWithCheckbox.self, forCellReuseIdentifier: TicketTableViewCellWithCheckbox.identifier)
        tableView.register(TokenListFormatTableViewCellWithCheckbox.self, forCellReuseIdentifier: TokenListFormatTableViewCellWithCheckbox.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.tableHeaderView = header
        tableView.rowHeight = UITableViewAutomaticDimension
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

    func configure(viewModel newViewModel: SellTicketsViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        tableView.dataSource = self
        updateNavigationRightBarButtons(isVerified: isContractVerified)

        header.configure(title: viewModel.title)
        tableView.tableHeaderView = header

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    @objc
    func nextButtonTapped() {
        let selectedTicketHolders = viewModel.ticketHolders.filter { $0.isSelected }
        if selectedTicketHolders.isEmpty {
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTicketTokenSellSelectTicketsAtLeastOneTitle(),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            self.delegate?.didSelectTicketHolder(ticketHolder: selectedTicketHolders.first!, in: self)
        }
    }

    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(in: self)
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
        let ticketHolder = viewModel.item(for: indexPath)
        let tokenType = CryptoKittyHandling(contract: ticketHolder.contractAddress)
        switch tokenType {
        case .cryptoKitty:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenListFormatTableViewCellWithCheckbox.identifier, for: indexPath) as! TokenListFormatTableViewCellWithCheckbox
            cell.delegate = self
            cell.configure(viewModel: .init(ticketHolder: ticketHolder))
            return cell
        case .otherNonFungibleToken:
            let cell = tableView.dequeueReusableCell(withIdentifier: TicketTableViewCellWithCheckbox.identifier, for: indexPath) as! TicketTableViewCellWithCheckbox
            cell.configure(viewModel: .init(ticketHolder: ticketHolder))
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let changedIndexPaths = viewModel.toggleSelection(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }
}

extension SellTicketsViewController: BaseTokenListFormatTableViewCellDelegate {
    func didTapURL(url: URL) {
        delegate?.didTapURL(url: url, in: self)
    }
}
