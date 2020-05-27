// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Result
import SafariServices

protocol TransactionViewControllerDelegate: class, CanOpenURL {
}

class TransactionViewController: UIViewController {
    private lazy var viewModel: TransactionDetailsViewModel = {
        return .init(
            transaction: transaction,
            chainState: session.chainState,
            currentWallet: session.account,
            currencyRate: session.balanceCoordinator.currencyRate
        )
    }()
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private let session: WalletSession
    private let transaction: Transaction

    weak var delegate: TransactionViewControllerDelegate?

    init(
        session: WalletSession,
        transaction: Transaction,
        delegate: TransactionViewControllerDelegate?
    ) {
        self.session = session
        self.transaction = transaction
        self.delegate = delegate

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
            item(title: viewModel.fromLabelTitle, value: viewModel.from),
            item(title: viewModel.toLabelTitle, value: viewModel.to),
            item(title: viewModel.gasFeeLabelTitle, value: viewModel.gasFee),
            item(title: viewModel.confirmationLabelTitle, value: viewModel.confirmation),
            .spacer(),
            item(title: viewModel.transactionIDLabelTitle, value: viewModel.transactionID),
            item(title: viewModel.createdAtLabelTitle, value: viewModel.createdAt),
            item(title: viewModel.blockNumberLabelTitle, value: viewModel.blockNumber),
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
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
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
        button.setTitle(R.string.localizable.moreDetails(), for: .normal)
        button.addTarget(self, action: #selector(more), for: .touchUpInside)

        buttonsBar.isHidden = !viewModel.detailsAvailable
    }

    private func item(title: String, value: String) -> UIView {
        return  TransactionAppearance.item(
            title: title,
            subTitle: value
        ) { [weak self] in
            self?.showAlertSheet(title: $0, value: $1, sourceView: $2)
        }
    }

    func showAlertSheet(title: String, value: String, sourceView: UIView) {
        let alertController = UIAlertController(
            title: nil,
            message: value,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sourceView
        alertController.popoverPresentationController?.sourceRect = sourceView.bounds
        let copyAction = UIAlertAction(title: R.string.localizable.copy(), style: .default) { _ in
            UIPasteboard.general.string = value
        }
        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        alertController.addAction(copyAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }

    @objc func more() {
        guard let url = viewModel.detailsURL else { return }
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
        fatalError("init(coder:) has not been implemented")
    }

    @objc func dismiss() {
        dismiss(animated: true, completion: nil)
    }
}
