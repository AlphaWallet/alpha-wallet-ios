// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import SafariServices
import MBProgressHUD
import AlphaWalletFoundation

protocol TransactionViewControllerDelegate: class, CanOpenURL {
}

class TransactionViewController: UIViewController {
    private let analytics: AnalyticsLogger
    private lazy var viewModel: TransactionDetailsViewModel = {
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: session.server)
        return .init(
            transactionRow: transactionRow,
            chainState: session.chainState,
            wallet: session.account,
            currencyRate: service.tokenViewModel(for: etherToken)?.balance.ticker?.rate
        )
    }()
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private let session: WalletSession
    private let transactionRow: TransactionRow
    private let service: TokenViewModelState
    weak var delegate: TransactionViewControllerDelegate?

    init(analytics: AnalyticsLogger, session: WalletSession, transactionRow: TransactionRow, service: TokenViewModelState, delegate: TransactionViewControllerDelegate?) {
        self.analytics = analytics
        self.session = session
        self.transactionRow = transactionRow
        self.delegate = delegate
        self.service = service

        super.init(nibName: nil, bundle: nil)

        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        let header = TransactionHeaderView(server: session.server)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.configure(amount: viewModel.amountAttributedString)

        let items: [UIView] = [
            .spacer(),
            header,
            .spacer(),
            item(title: viewModel.fromLabelTitle, value: viewModel.from, icon: R.image.copy()),
            item(title: viewModel.toLabelTitle, value: viewModel.to, icon: R.image.copy()),
            item(title: viewModel.gasFeeLabelTitle, value: viewModel.gasFee),
            item(title: viewModel.confirmationLabelTitle, value: viewModel.confirmation),
            .spacer(),
            item(title: viewModel.transactionIDLabelTitle, value: viewModel.transactionID, icon: R.image.copy()),
            item(title: viewModel.createdAtLabelTitle, value: viewModel.createdAt),
            item(title: viewModel.blockNumberLabelTitle, value: viewModel.blockNumber),
            item(title: viewModel.nonceLabelTitle, value: viewModel.nonce),
        ]

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        let stackView = items.asStackView(axis: .vertical, spacing: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        if viewModel.shareAvailable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share(_:)))
        }

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: HorizontalButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -HorizontalButtonsBar.buttonsHeight - HorizontalButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let buttonsBarHolder = buttonsBar.superview else {
            scrollView.contentInset = .zero
            return
        }
        //TODO We are basically calculating the bottom safe area here. Don't rely on the internals of how buttonsBar and it's parent are laid out
        if buttonsBar.isEmpty {
            scrollView.contentInset = .init(top: 0, left: 0, bottom: buttonsBarHolder.frame.size.height - buttonsBar.frame.size.height, right: 0)
        } else {
            scrollView.contentInset = .init(top: 0, left: 0, bottom: scrollView.frame.size.height - buttonsBarHolder.frame.origin.y, right: 0)
        }
    }

    private func configure() {
        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.setTitle(viewModel.detailsButtonText, for: .normal)
        button.addTarget(self, action: #selector(more), for: .touchUpInside)

        buttonsBar.isHidden = !viewModel.detailsAvailable
    }

    private func item(title: String, value: String, icon: UIImage? = nil) -> UIView {
        return TransactionAppearance.item(
            title: title,
            subTitle: value,
            icon: icon
        ) { [weak self] _, _, _ in
            self?.copy(value: value, showHUD: icon != nil)
        }
    }

    @objc func copy(value: String, showHUD: Bool = false) {
        UIPasteboard.general.string = value

        if showHUD {
            let hud = MBProgressHUD.showAdded(to: view, animated: true)
            hud.mode = .text
            hud.label.text = viewModel.addressCopiedText
            hud.hide(animated: true, afterDelay: 1.5)

            showFeedback()
        }
    }

    private func showFeedback() {
        UINotificationFeedbackGenerator.show(feedbackType: .success)
    }

    @objc func more() {
        guard let url = viewModel.detailsURL else { return }
        logUse()
        delegate?.didPressOpenWebPage(url, in: self)
    }

    @objc func share(_ sender: UIBarButtonItem) {
        guard let item = viewModel.shareItem else { return }
        let activityViewController = UIActivityViewController(
            activityItems: [
                item,
            ],
            applicationActivities: nil
        )
        activityViewController.popoverPresentationController?.barButtonItem = sender
        navigationController?.present(activityViewController, animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc func dismiss() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: Analytics
extension TransactionViewController {
    private func logUse() {
        analytics.log(navigation: Analytics.Navigation.explorer, properties: [Analytics.Properties.type.rawValue: Analytics.ExplorerType.transaction.rawValue])
    }
}
