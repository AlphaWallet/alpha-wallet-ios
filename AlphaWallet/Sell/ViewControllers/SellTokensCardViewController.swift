// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol SellTokensCardViewControllerDelegate: class, CanOpenURL {
    func didSelectTokenHolder(tokenHolder: TokenHolder, in viewController: SellTokensCardViewController)
    func didPressViewInfo(in viewController: SellTokensCardViewController)
    func didTapURL(url: URL, in viewController: SellTokensCardViewController)
}

class SellTokensCardViewController: UIViewController, TokenVerifiableStatusViewController {
    private let roundedBackground = RoundedBackground()
    private let header = TokensCardViewControllerTitleHeader()
    private let tableView = UITableView(frame: .zero, style: .plain)
	private let nextButton = UIButton(type: .system)
    private var viewModel: SellTokensCardViewModel

    let config: Config
    var contract: String {
        return viewModel.token.contract
    }
    let paymentFlow: PaymentFlow
    weak var delegate: SellTokensCardViewControllerDelegate?

    init(config: Config, paymentFlow: PaymentFlow, viewModel: SellTokensCardViewModel) {
        self.config = config
        self.paymentFlow = paymentFlow
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.register(TokenCardTableViewCellWithCheckbox.self, forCellReuseIdentifier: TokenCardTableViewCellWithCheckbox.identifier)
        tableView.register(CryptoKittyTokenCardTableViewCellWithCheckbox.self, forCellReuseIdentifier: CryptoKittyTokenCardTableViewCellWithCheckbox.identifier)
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

    func configure(viewModel newViewModel: SellTokensCardViewModel? = nil) {
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
        let selectedTokenHolders = viewModel.tokenHolders.filter { $0.isSelected }
        if selectedTokenHolders.isEmpty {
            let tokenTypeName = XMLHandler(contract: contract).getTokenTypeName(.singular, titlecase: .notTitlecase)
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTokenSellSelectTokensAtLeastOneTitle(tokenTypeName),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectTokenHolder(tokenHolder: selectedTokenHolders.first!, in: self)
        }
    }

    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, in: self)
    }

    private func animateRowHeightChanges(for indexPaths: [IndexPath], in tableview: UITableView) {
        tableView.reloadData()
    }
}

extension SellTokensCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tokenHolder = viewModel.item(for: indexPath)
        let tokenType = CryptoKittyHandling(contract: tokenHolder.contractAddress)
        switch tokenType {
        case .cryptoKitty:
            let cell = tableView.dequeueReusableCell(withIdentifier: CryptoKittyTokenCardTableViewCellWithCheckbox.identifier, for: indexPath) as! CryptoKittyTokenCardTableViewCellWithCheckbox
            cell.delegate = self
            cell.configure(viewModel: .init(tokenHolder: tokenHolder))
            return cell
        case .otherNonFungibleToken:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenCardTableViewCellWithCheckbox.identifier, for: indexPath) as! TokenCardTableViewCellWithCheckbox
            cell.configure(viewModel: .init(tokenHolder: tokenHolder))
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let changedIndexPaths = viewModel.toggleSelection(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }
}

extension SellTokensCardViewController: BaseCryptoKittyTokenCardTableViewCellDelegate {
    func didTapURL(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}
