// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TransferTokensCardViewControllerDelegate: class, CanOpenURL {
    func didSelectTokenHolder(token: TokenObject, tokenHolder: TokenHolder, in viewController: TransferTokensCardViewController)
    func didPressViewInfo(in viewController: TransferTokensCardViewController)
    func didTapURL(url: URL, in viewController: TransferTokensCardViewController)
}

class TransferTokensCardViewController: UIViewController, TokenVerifiableStatusViewController {
    private let roundedBackground = RoundedBackground()
    private let header = TokensCardViewControllerTitleHeader()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var nextButtonContainer = ContainerViewWithShadow(aroundView: UIButton(type: .system))
    private var viewModel: TransferTokensCardViewModel
    private let token: TokenObject

    let config: Config
    var contract: String {
        return viewModel.token.contract
    }
    var paymentFlow: PaymentFlow
    weak var delegate: TransferTokensCardViewControllerDelegate?

    init(config: Config, paymentFlow: PaymentFlow, token: TokenObject, viewModel: TransferTokensCardViewModel) {
        self.config = config
        self.paymentFlow = paymentFlow
        self.token = token
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.register(TokenCardTableViewCellWithCheckbox.self, forCellReuseIdentifier: TokenCardTableViewCellWithCheckbox.identifier)
        tableView.register(OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox.self, forCellReuseIdentifier: OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.tableHeaderView = header
        tableView.estimatedRowHeight = TokensCardViewController.anArbitaryRowHeightSoAutoSizingCellsWorkIniOS10
        roundedBackground.addSubview(tableView)

        let nextButton = nextButtonContainer.childView
        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        let buttonsStackView = [.spacerWidth(20), nextButtonContainer, .spacerWidth(20)].asStackView(contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = Metrics.greenButtonHeight
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
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -buttonsHeight - 3),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel newViewModel: TransferTokensCardViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        tableView.dataSource = self
        updateNavigationRightBarButtons(isVerified: isContractVerified)

        header.configure(title: viewModel.title)
        tableView.tableHeaderView = header

        nextButtonContainer.configureShadow(color: viewModel.actionButtonShadowColor, offset: viewModel.actionButtonShadowOffset, opacity: viewModel.actionButtonShadowOpacity, radius: viewModel.actionButtonShadowRadius, cornerRadius: viewModel.actionButtonCornerRadius)
        let nextButton = nextButtonContainer.childView
        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    @objc
    func nextButtonTapped() {
        let selectedTokenHolders = viewModel.tokenHolders.filter { $0.isSelected }
        if selectedTokenHolders.isEmpty {
            let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName(.singular, titlecase: .notTitlecase)
            UIAlertController.alert(title: "",
                                    message: R.string.localizable.aWalletTokenTransferSelectTokensAtLeastOneTitle(tokenTypeName),
                                    alertButtonTitles: [R.string.localizable.oK()],
                                    alertButtonStyles: [.cancel],
                                    viewController: self,
                                    completion: nil)
        } else {
            delegate?.didSelectTokenHolder(token: viewModel.token, tokenHolder: selectedTokenHolders.first!, in: self)
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

extension TransferTokensCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tokenHolder = viewModel.item(for: indexPath)
        let tokenType = OpenSeaNonFungibleTokenHandling(token: token)
        switch tokenType {
        case .supportedByOpenSea:
            let cell = tableView.dequeueReusableCell(withIdentifier: OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox.identifier, for: indexPath) as! OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox
            cell.delegate = self
            cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width))
            return cell
        case .notSupportedByOpenSea:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenCardTableViewCellWithCheckbox.identifier, for: indexPath) as! TokenCardTableViewCellWithCheckbox
            cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width))
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let changedIndexPaths = viewModel.toggleSelection(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }
}

extension TransferTokensCardViewController: BaseOpenSeaNonFungibleTokenCardTableViewCellDelegate {
    func didTapURL(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}
