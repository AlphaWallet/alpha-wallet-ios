// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import UIKit
import StackViewController
import Result

enum ConfirmType {
    case sign
    case signThenSend
}

enum ConfirmResult {
    case signedTransaction(Data)
    case sentTransaction(SentTransaction)
}

class ConfirmPaymentViewController: UIViewController {
    private let keystore: Keystore
    //let transaction: UnconfirmedTransaction
    private let session: WalletSession
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        return stackView
    }()
    private lazy var sendTransactionCoordinator = {
        return SendTransactionCoordinator(session: session, keystore: keystore, confirmType: confirmType)
    }()
    private let scrollView = UIScrollView()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private let viewModel = ConfirmPaymentViewModel()
    private let configurator: TransactionConfigurator
    private let confirmType: ConfirmType

    var didCompleted: ((Result<ConfirmResult, AnyError>) -> Void)?

    init(
        session: WalletSession,
        keystore: Keystore,
        configurator: TransactionConfigurator,
        confirmType: ConfirmType
    ) {
        self.session = session
        self.keystore = keystore
        self.configurator = configurator
        self.confirmType = confirmType

        super.init(nibName: nil, bundle: nil)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.settings_icon(), style: .plain, target: self, action: #selector(edit))
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.title

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        view.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
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
        ])

        configurator.load { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success:
                strongSelf.reloadView()
            case .failure(let error):
                strongSelf.displayError(error: error)
            }
        }
        configurator.configurationUpdate.subscribe { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.reloadView()
        }
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
            let yMargin = CGFloat(7)
            scrollView.contentInset = .init(top: 0, left: 0, bottom: scrollView.frame.size.height - buttonsBarHolder.frame.origin.y + yMargin, right: 0)
        }
    }

    private func configure(for detailsViewModel: ConfirmPaymentDetailsViewModel) {
        let header = TransactionHeaderView(server: session.server)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.configure(amount: detailsViewModel.amountAttributedString)

        let nonceRow = TransactionAppearance.item(title: detailsViewModel.nonceTitle, subTitle: detailsViewModel.nonceText) { [unowned self] _, _, _ in
            self.edit()
        }
        nonceRow.isHidden = !detailsViewModel.isNonceSet
        let items: [UIView] = [
            .spacer(),
            header,
            .spacer(),
            TransactionAppearance.item(
                title: detailsViewModel.paymentFromTitle,
                subTitle: session.account.address.eip55String
            ),
            TransactionAppearance.item(
                title: detailsViewModel.paymentToTitle,
                subTitle: detailsViewModel.paymentToText
            ),
            TransactionAppearance.item(
                title: detailsViewModel.gasLimitTitle,
                subTitle: detailsViewModel.gasLimitText
            ) { [unowned self] _, _, _ in
                self.edit()
            },
            TransactionAppearance.item(
                title: detailsViewModel.gasPriceTitle,
                subTitle: detailsViewModel.gasPriceText
            ) { [unowned self] _, _, _ in
                self.edit()
            },
            TransactionAppearance.item(
                title: detailsViewModel.feeTitle,
                subTitle: detailsViewModel.feeText
            ) { [unowned self] _, _, _ in
                self.edit()
            },
            nonceRow,
            TransactionAppearance.item(
                title: detailsViewModel.dataTitle,
                subTitle: detailsViewModel.dataText
            ) { [unowned self] _, _, _ in
                self.edit()
            },
        ]

        stackView.removeAllArrangedSubviews()
        stackView.addArrangedSubviews(items)

        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.setTitle(viewModel.sendButtonText, for: .normal)
        button.addTarget(self, action: #selector(send), for: .touchUpInside)
    }

    private func reloadView() {
        let viewModel = ConfirmPaymentDetailsViewModel(
            transaction: configurator.previewTransaction(),
            server: session.server,
            currentBalance: session.balance,
            currencyRate: session.balanceCoordinator.currencyRate
        )
        configure(for: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func edit() {
        let controller = ConfigureTransactionViewController(
            configuration: configurator.configuration,
            transferType: configurator.transaction.transferType,
            server: session.server,
            currencyRate: session.balanceCoordinator.currencyRate
        )
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc func send() {
        displayLoading()

        let transaction = configurator.formUnsignedTransaction()
        sendTransactionCoordinator.send(transaction: transaction) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.didCompleted?(result)
            strongSelf.hideLoading()
            strongSelf.showFeedbackOnSuccess(result)
        }
    }

    private func showFeedbackOnSuccess(_ result: Result<ConfirmResult, AnyError>) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        switch result {
        case .success:
            //Hackish, but delay necessary because of the switch to and from user-presence for signing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                //TODO sound too
                feedbackGenerator.notificationOccurred(.success)
            }
        case .failure:
            break
        }
    }
}

extension ConfirmPaymentViewController: ConfigureTransactionViewControllerDelegate {
    func didEdit(configuration: TransactionConfiguration, in viewController: ConfigureTransactionViewController) {
        configurator.update(configuration: configuration)
        navigationController?.popViewController(animated: true)
    }
}
