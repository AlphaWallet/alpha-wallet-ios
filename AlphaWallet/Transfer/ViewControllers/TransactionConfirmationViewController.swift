// Copyright © 2020 Stormbird PTE. LTD.

import BigInt
import Foundation
import UIKit
import Result
import Combine

protocol TransactionConfirmationViewControllerDelegate: AnyObject {
    func controller(_ controller: TransactionConfirmationViewController, continueButtonTapped sender: UIButton)
    func controllerDidTapEdit(_ controller: TransactionConfirmationViewController)
    func didClose(in controller: TransactionConfirmationViewController)
    func didInvalidateLayout(in controller: TransactionConfirmationViewController)
}

class TransactionConfirmationViewController: UIViewController {
    enum State {
        case ready
        case pending
        case done(withError: Bool)
    }

    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var viewModel: TransactionConfirmationViewModel
    private var timerToReenableConfirmButton: Timer?
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()
        return view
    }()
    private let loadingIndicatorView = ActivityIndicatorControl()
    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = viewModel.footerBackgroundColor
        view.addSubview(buttonsBar)
        view.addSubview(loadingIndicatorView)

        return view
    }()
    private let containerView = ScrollableStackView()
    private lazy var heightConstraint: NSLayoutConstraint = {
        return view.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()

    private let session: WalletSession
    private var canBeConfirmed = true
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: TransactionConfirmationViewControllerDelegate?

// swiftlint:disable function_body_length
    init(viewModel: TransactionConfirmationViewModel, session: WalletSession) {
        self.viewModel = viewModel
        self.session = session
        super.init(nibName: nil, bundle: nil)

        view.addSubview(containerView)
        view.addSubview(footerBar)
        view.addSubview(headerView)
        view.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            heightConstraint,
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),

            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            separatorLine.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.separatorHeight),
            separatorLine.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: HorizontalButtonsBar.buttonsHeight),

            loadingIndicatorView.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            loadingIndicatorView.centerXAnchor.constraint(equalTo: footerBar.centerXAnchor)
        ])

        headerView.closeButton.addTarget(self, action: #selector(closeButtonSelected), for: .touchUpInside)

        let scrollView = containerView.scrollView

        scrollView
            .publisher(for: \.contentSize, options: [.new, .initial])
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }

                let statusBarHeight = UIView.statusBarFrame.height
                let contentHeight = scrollView.contentSize.height + DataEntry.Metric.TransactionConfirmation.footerHeight + DataEntry.Metric.TransactionConfirmation.headerHeight
                let newHeight = min(UIScreen.main.bounds.height - statusBarHeight, contentHeight)

                let fillScreenPercentage = strongSelf.heightConstraint.constant / UIScreen.main.bounds.height - statusBarHeight

                if fillScreenPercentage >= 0.9 {
                    strongSelf.heightConstraint.constant = UIScreen.main.bounds.height - statusBarHeight
                } else {
                    strongSelf.heightConstraint.constant = newHeight
                }

            }.store(in: &cancelable)

        session
            .tokenBalanceService
            .etherToFiatRatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] price in
                viewModel.cryptoToFiatRateUpdatable.cryptoToDollarRate = price
                self?.generateSubviews()
            }.store(in: &cancelable)

        switch viewModel {
        case .dappOrWalletConnectTransaction(let dappTransactionViewModel):
            headerView.iconImageView.setImage(url: dappTransactionViewModel.dappIconUrl, placeholder: dappTransactionViewModel.placeholderIcon)
        case .sendFungiblesTransaction(let sendFungiblesViewModel):
            sendFungiblesViewModel.recipientResolver.resolveRecipient()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.generateSubviews()
                }.store(in: &cancelable)

            switch sendFungiblesViewModel.transactionType {
            case .nativeCryptocurrency:
                sendFungiblesViewModel.session
                    .tokenBalanceService
                    .etherBalance
                    .receive(on: RunLoop.main)
                    .sink { [weak self] balanceBaseViewModel in
                        sendFungiblesViewModel.updateBalance(.nativeCryptocurrency(balanceViewModel: balanceBaseViewModel))
                        self?.generateSubviews()
                    }.store(in: &cancelable)
                
                sendFungiblesViewModel.session.tokenBalanceService.refresh(refreshBalancePolicy: .eth)
            case .erc20Token(let token, _, _):
                sendFungiblesViewModel.updateBalance(.erc20(token: token))
            case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                break
            }
        case .sendNftTransaction(let sendNftViewModel):
            sendNftViewModel.recipientResolver.resolveRecipient()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.generateSubviews()
                }.store(in: &cancelable)
        case .tokenScriptTransaction, .claimPaidErc875MagicLink, .speedupTransaction, .cancelTransaction, .swapTransaction:
            break
        }

        generateSubviews()
    }
// swiftlint:enable function_body_length
    
    override func viewDidLoad() {
        super.viewDidLoad()

        set(state: .ready)
        configure(for: viewModel)
    }

    func set(state: State, completion: (() -> Void)? = nil) {
        let confirmationButton = buttonsBar.buttons[0]
        switch state {
        case .ready:
            buttonsBar.isHidden = false
            loadingIndicatorView.isHidden = true
        case .pending:
            confirmationButton.startAnimation(completion: { [weak self] in
                self?.buttonsBar.isHidden = true
                self?.loadingIndicatorView.isHidden = false
                self?.loadingIndicatorView.startAnimating()
            })
        case .done(let hasError):
            buttonsBar.isHidden = true
            loadingIndicatorView.isHidden = false
            loadingIndicatorView.stopAnimating(completion: { [weak self] in
                self?.buttonsBar.isHidden = false
                self?.loadingIndicatorView.isHidden = true
                let animationStyle: StopAnimationStyle = {
                    if hasError {
                        return .shake
                    } else {
                        return .normal
                    }
                }()
                confirmationButton.stopAnimation(animationStyle: animationStyle, completion: completion)
            })
        }
    }

    @objc private func closeButtonSelected(_ sender: UIButton) {
        delegate?.didClose(in: self)
    }

    func reloadView() {
        generateSubviews()
    }

    func reloadViewWithGasChanges() {
        canBeConfirmed = false
        reloadView()
        createTimerToRestoreConfirmButton()
    }

    //NOTE: we need to recalculate all funds value to send according to updated gas estimates, nativecrypto only
    func reloadViewWithCurrentBalanceValue() {
        switch viewModel {
        case .dappOrWalletConnectTransaction, .tokenScriptTransaction, .speedupTransaction, .cancelTransaction, .swapTransaction:
            break
        case .sendFungiblesTransaction(let sendFungiblesViewModel):
            switch sendFungiblesViewModel.transactionType {
            case .nativeCryptocurrency:
                let balanceBaseViewModel = sendFungiblesViewModel.session.tokenBalanceService.ethBalanceViewModel

                sendFungiblesViewModel.updateBalance(.nativeCryptocurrency(balanceViewModel: balanceBaseViewModel))
            case .erc20Token, .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                break
            }
        case .sendNftTransaction, .claimPaidErc875MagicLink:
            break
        }
    }

    private func createTimerToRestoreConfirmButton() {
        timerToReenableConfirmButton?.invalidate()
        let gap = TimeInterval(0.3)
        timerToReenableConfirmButton = Timer.scheduledTimer(withTimeInterval: gap, repeats: false) { [weak self] _ in
            self?.canBeConfirmed = true
        }
    }

    private func configure(for viewModel: TransactionConfirmationViewModel) {
        containerView.scrollView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.title

        separatorLine.isHidden = !viewModel.hasSeparatorAboveConfirmButton

        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.shrinkBorderColor = Colors.loadingIndicatorBorder
        button.setTitle(viewModel.confirmationButtonTitle, for: .normal)
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
    }

    @objc func confirmButtonTapped(_ sender: UIButton) {
        guard canBeConfirmed else { return }
        delegate?.controller(self, continueButtonTapped: sender)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension TransactionConfirmationViewController {
    // swiftlint:disable function_body_length
    private func generateSubviews() {
        containerView.stackView.removeAllArrangedSubviews()
        var views: [UIView] = []
        switch viewModel {
        case .dappOrWalletConnectTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                var children: [UIView] = []
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self

                switch section {
                case .gas:
                    if viewModel.server.canUserChangeGas {
                        header.enableTapAction(title: R.string.localizable.editButtonTitle())
                    } else {
                        //no-op
                    }
                case .amount, .network:
                    break
                case .function(let functionCallMetaData):
                    let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex)
                    let view = TransactionConfirmationRowInfoView(viewModel: .init(title: "\(functionCallMetaData.name)()", subtitle: ""))
                    view.isHidden = isSubViewsHidden
                    children.append(view)

                    for arg in functionCallMetaData.arguments {
                        let view = TransactionConfirmationRowInfoView(viewModel: .init(title: arg.type.description, subtitle: arg.description))
                        view.isHidden = isSubViewsHidden
                        children.append(view)
                    }
                }
                header.childrenStackView.addArrangedSubviews(children)
                header.childrenStackView.isHidden = children.isEmpty
                views.append(header)
            }
        case .tokenScriptTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                var children: [UIView] = []
                switch section {
                case .gas:
                    if viewModel.server.canUserChangeGas {
                        header.enableTapAction(title: R.string.localizable.editButtonTitle())
                    } else {
                        //no-op
                    }
                case .function:
                    let isSubViewsHidden = viewModel.isSubviewsHidden(section: sectionIndex)
                    let view = TransactionConfirmationRowInfoView(viewModel: .init(title: "\(viewModel.functionCallMetaData.name)()", subtitle: ""))
                    view.isHidden = isSubViewsHidden
                    children.append(view)

                    for arg in viewModel.functionCallMetaData.arguments {
                        let view = TransactionConfirmationRowInfoView(viewModel: .init(title: arg.type.description, subtitle: arg.description))
                        view.isHidden = isSubViewsHidden
                        children.append(view)
                    }
                case .contract, .amount, .network:
                    break
                }
                header.childrenStackView.addArrangedSubviews(children)
                header.childrenStackView.isHidden = children.isEmpty
                views.append(header)
            }
        case .sendFungiblesTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                var children: [UIView] = []
                switch section {
                case .recipient:
                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        switch row {
                        case .ens:
                            let view = TransactionConfirmationRowInfoView(viewModel: .init(title: R.string.localizable.transactionConfirmationRowTitleEns(), subtitle: viewModel.ensName))
                            view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                            children.append(view)
                        case .address:
                            let view = TransactionConfirmationRowInfoView(viewModel: .init(title: R.string.localizable.transactionConfirmationRowTitleWallet(), subtitle: viewModel.addressString))
                            view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                            children.append(view)
                        }
                    }
                case .gas:
                    if viewModel.server.canUserChangeGas {
                        header.enableTapAction(title: R.string.localizable.editButtonTitle())
                    } else {
                        //no-op
                    }
                case .amount, .balance, .network:
                    break
                }
                header.childrenStackView.addArrangedSubviews(children)
                header.childrenStackView.isHidden = children.isEmpty
                views.append(header)
            }
        case .sendNftTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                var children: [UIView] = []
                switch section {
                case .recipient:
                    for (rowIndex, row) in RecipientResolver.Row.allCases.enumerated() {
                        switch row {
                        case .ens:
                            let view = TransactionConfirmationRowInfoView(viewModel: .init(title: R.string.localizable.transactionConfirmationRowTitleEns(), subtitle: viewModel.ensName))
                            view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                            children.append(view)
                        case .address:
                            let view = TransactionConfirmationRowInfoView(viewModel: .init(title: R.string.localizable.transactionConfirmationRowTitleWallet(), subtitle: viewModel.addressString))
                            view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)
                            children.append(view)
                        }
                    }
                case .gas:
                    if viewModel.server.canUserChangeGas {
                        header.enableTapAction(title: R.string.localizable.editButtonTitle())
                    } else {
                        //no-op
                    }
                case .tokenId:
                    //NOTE: Maybe its needed to update with something else
                    let tokenIdsAndValuesViews = viewModel.tokenIdAndValueViewModels().enumerated().map { (index, value) -> UIView in
                        let view = TransactionConfirmationRowInfoView(viewModel: .init(title: value, subtitle: ""))
                        view.isHidden = viewModel.isSubviewsHidden(section: sectionIndex, row: index)
                        return view
                    }

                    children.append(UIView.spacer(height: 20))
                    children.append(contentsOf: tokenIdsAndValuesViews)
                case .network:
                    break
                }
                header.childrenStackView.addArrangedSubviews(children)
                header.childrenStackView.isHidden = children.isEmpty
                views.append(header)
            }
        case .claimPaidErc875MagicLink(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                switch section {
                case .gas:
                    if viewModel.server.canUserChangeGas {
                        header.enableTapAction(title: R.string.localizable.editButtonTitle())
                    } else {
                        //no-op
                    }
                case .amount, .numberOfTokens, .network:
                    break
                }
                views.append(header)
            }
        case .speedupTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let children: [UIView] = []

                switch section {
                case .gas:
                    if viewModel.server.canUserChangeGas {
                        let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                        header.delegate = self
                        header.enableTapAction(title: R.string.localizable.editButtonTitle())
                        header.childrenStackView.addArrangedSubviews(children)
                        views.append(header)
                    } else {
                        //no-op
                    }
                case .description:
                    let view = TransactionConfirmationRowDescriptionView(viewModel: .init(title: section.title))
                    views.append(view)
                }
            }
        case .cancelTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let children: [UIView] = []

                switch section {
                case .gas:
                    if viewModel.server.canUserChangeGas {
                        let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                        header.delegate = self
                        header.enableTapAction(title: R.string.localizable.editButtonTitle())
                        header.childrenStackView.addArrangedSubviews(children)
                        views.append(header)
                    } else {
                        //no-op
                    }
                case .description:
                    let view = TransactionConfirmationRowDescriptionView(viewModel: .init(title: section.title))
                    views.append(view)
                }
            }
        case .swapTransaction(let viewModel):
            for (sectionIndex, section) in viewModel.sections.enumerated() {
                let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
                header.delegate = self
                let children: [UIView] = []
                switch section {
                case .gas:
                    if viewModel.server.canUserChangeGas {
                        header.enableTapAction(title: R.string.localizable.editButtonTitle())
                    } else {
                        //no-op
                    }
                case .network, .from, .to:
                    break
                }
                header.childrenStackView.addArrangedSubviews(children)
                header.childrenStackView.isHidden = children.isEmpty
                views.append(header)
            }
        }
        containerView.stackView.addArrangedSubviews(views)
    }
    // swiftlint:enable function_body_length
}

extension TransactionConfirmationViewController: TransactionConfirmationHeaderViewDelegate {

    func headerView(_ header: TransactionConfirmationHeaderView, shouldHideChildren section: Int, index: Int) -> Bool {
        return true
    }

    func headerView(_ header: TransactionConfirmationHeaderView, shouldShowChildren section: Int, index: Int) -> Bool {
        switch viewModel {
        case .dappOrWalletConnectTransaction, .claimPaidErc875MagicLink, .tokenScriptTransaction, .speedupTransaction, .cancelTransaction, .swapTransaction:
            return true
        case .sendFungiblesTransaction(let viewModel):
            switch viewModel.sections[section] {
            case .recipient, .network:
                return !viewModel.isSubviewsHidden(section: section, row: index)
            case .gas, .amount, .balance:
                return true
            }
        case .sendNftTransaction(let viewModel):
            switch viewModel.sections[section] {
            case .recipient, .network:
                //NOTE: Here we need to make sure that this view is available to display
                return !viewModel.isSubviewsHidden(section: section, row: index)
            case .gas, .tokenId:
                return true
            }
        }
    }

    func headerView(_ header: TransactionConfirmationHeaderView, openStateChanged section: Int) {
        switch viewModel.showHideSection(section) {
        case .show:
            header.expand()
        case .hide:
            header.collapse()
        }

        UIView.animate(withDuration: 0.35) {
            self.view.layoutIfNeeded()
            self.delegate?.didInvalidateLayout(in: self)
        }
    }

    func headerView(_ header: TransactionConfirmationHeaderView, tappedSection section: Int) {
        delegate?.controllerDidTapEdit(self)
    }
}
