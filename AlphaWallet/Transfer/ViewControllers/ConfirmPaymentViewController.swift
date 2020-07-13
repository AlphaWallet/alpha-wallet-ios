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

class ConfirmPaymentViewController: UIViewController, UpdatablePreferredContentSize {
    private let account: EthereumAccount
    private let keystore: Keystore
    private let session: WalletSession
    private lazy var sendTransactionCoordinator = {
        return SendTransactionCoordinator(session: session, keystore: keystore, confirmType: confirmType)
    }()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private lazy var viewModel = ConfirmPaymentDetailsViewModel(
        transaction: configurator.previewTransaction(),
        server: session.server,
        currentBalance: session.balance,
        currencyRate: session.balanceCoordinator.currencyRate,
        session: session,
        account: account,
        ensName: ensName
    )
    private var configurator: TransactionConfigurator
    private let confirmType: ConfirmType
    private var ensName: String?

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.registerHeaderFooterView(ConfirmTransactionTableViewHeader.self)
        tableView.register(ConfirmTransactionTableViewCell.self)
        tableView.register(EditGasTableViewCell.self)
        tableView.separatorStyle = .none
        
        return tableView
    }()

    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()

        return view
    }()

    var didCompleted: ((Result<ConfirmResult, AnyError>) -> Void)?

    private var contentSizeObservation: NSKeyValueObservation!
    private let footerHeight: CGFloat = 120
    private var contentSize: CGSize {
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let height = min(UIScreen.main.bounds.height - statusBarHeight, tableView.contentSize.height + footerHeight + 1.0)
        return CGSize(width: UIScreen.main.bounds.width, height: height)
    }

//    private let loadingIndicatorView: CircularProgressView = {
//        let view = CircularProgressView()
//        view.translatesAutoresizingMaskIntoConstraints = false
//        return view
//    }()

    //NOTE: we are using flag to disable animation until first UITableView open/hide action
    var updatePreferredContentSizeAnimated: Bool = false

    init(
        session: WalletSession,
        keystore: Keystore,
        configurator: TransactionConfigurator,
        confirmType: ConfirmType,
        account: EthereumAccount
    ) {
        self.account = account
        self.session = session
        self.keystore = keystore
        self.configurator = configurator
        self.confirmType = confirmType

        super.init(nibName: nil, bundle: nil)

        tableView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.title
        view.addSubview(tableView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = viewModel.backgroundColor
        view.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)
//        buttonsBar.isHidden = true
//        footerBar.addSubview(loadingIndicatorView)

        view.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: separatorLine.topAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

//            loadingIndicatorView.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
//            loadingIndicatorView.centerXAnchor.constraint(equalTo: footerBar.centerXAnchor),
//            loadingIndicatorView.widthAnchor.constraint(equalToConstant: 50),
//            loadingIndicatorView.heightAnchor.constraint(equalToConstant: 50),

            separatorLine.heightAnchor.constraint(equalToConstant: 1.0),
            separatorLine.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        title = viewModel.navigationTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem.appIconBarButton
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.close(), style: .plain, target: self, action: #selector(dismissVC))

        let throttler = Throttler(minimumDelay: 0.05)
        //NOTE: we observe UITableView.contentSize to determine view controller height.
        //we are using Throttler because during UITableViewUpdate procces contentSize changes with range of values, so we need latest valid value.
        contentSizeObservation = tableView.observe(\.contentSize, options: [.new, .initial]) { [weak self] _, _ in
            throttler.throttle { [weak self] in
                guard let strongSelf = self, let controller = strongSelf.navigationController else { return }
                controller.preferredContentSize = strongSelf.contentSize
            }
        }

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

    deinit {
        contentSizeObservation.invalidate()
    }
    
    @objc private func dismissVC() {
        dismiss(animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

//        loadingIndicatorView.progressAnimation(5)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
//        loadingIndicatorView.layoutIfNeeded()
    }

    private func configure(for detailsViewModel: ConfirmPaymentDetailsViewModel) {
        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.setTitle(viewModel.sendButtonText, for: .normal)
        button.addTarget(self, action: #selector(send), for: .touchUpInside)

        tableView.reloadData()
    }

    private func reloadView() {
        let viewModel = ConfirmPaymentDetailsViewModel(
            transaction: configurator.previewTransaction(),
            server: session.server,
            currentBalance: session.balance,
            currencyRate: session.balanceCoordinator.currencyRate,
            session: session,
            account: account,
            ensName: ensName
        )

        configure(for: viewModel)
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

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension ConfirmPaymentViewController: ConfigureTransactionViewControllerDelegate {
    func didEdit(configuration: TransactionConfiguration, in viewController: ConfigureTransactionViewController) {
        configurator.update(configuration: configuration)
        reloadView()

        navigationController?.popViewController(animated: true)
    }
}

extension ConfirmPaymentViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        //FIXME: remove later
        switch viewModel.sections[indexPath.section] {
        case .gas:
            edit()
        case .amount, .balance, .recipient:
            break
        }
    }
}

extension ConfirmPaymentViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ConfirmTransactionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: viewModel.title(indexPath: indexPath))

        return cell
    }

    private func configureTransactionTableViewHeaderWithResolvedESN(_ section: Int, header: ConfirmTransactionTableViewHeader) {
        header.delegate = self
        header.configure(viewModel: .init(
            title: viewModel.addressReplacedWithESN(ensName),
            placeholder: viewModel.sections[section].title,
            isOpened: viewModel.openedSections.contains(section),
            section: section
        ))

        //FIXME: Replace later with resolving ENS name
        
//        guard ensName == nil else { return }
//
//        let serverToResolveEns = RPCServer.main
//        let address = account.address
//
//        ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: address) { [weak self] result in
//            guard let strongSelf = self else { return }
//            strongSelf.ensName = result.value
//
//            header.configure(viewModel: .init(
//                title: strongSelf.viewModel.addressReplacedWithESN(result.value),
//                placeholder: placeholder,
//                isOpened: isOpened,
//                section: section
//            ))
//        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let isOpened = viewModel.openedSections.contains(section)
        let placeholder = viewModel.sections[section].title

        switch viewModel.sections[section] {
        case .recipient:
            let header: ConfirmTransactionTableViewHeader = tableView.dequeueReusableHeaderFooterView()
            header.delegate = self
            configureTransactionTableViewHeaderWithResolvedESN(section, header: header)

            return header
        case .balance, .gas:
            let header: ConfirmTransactionTableViewHeader = tableView.dequeueReusableHeaderFooterView()
            header.delegate = self
            header.configure(viewModel: .init(
                title: "Default",
                placeholder: placeholder,
                isOpened: isOpened,
                section: section
            ))

            return header
        case .amount:
            let header: ConfirmTransactionTableViewHeader = tableView.dequeueReusableHeaderFooterView()
            header.delegate = self
            header.configure(viewModel: .init(
                title: viewModel.amountAttributedString.string,
                placeholder: placeholder,
                isOpened: isOpened,
                section: section,
                shouldHideExpandButton: viewModel.numberOfRows(in: section) == 0
            ))

            return header
        }

    }
}

extension ConfirmPaymentViewController: ConfirmTransactionTableViewHeaderDelegate {

    func headerView(_ header: ConfirmTransactionTableViewHeader, didSelectExpand sender: UIButton, section: Int) {
        updatePreferredContentSizeAnimated = true

        if !viewModel.openedSections.contains(section) {
            viewModel.openedSections.insert(section)

            tableView.insertRows(at: viewModel.indexPaths(for: section), with: .none)
        } else {
            viewModel.openedSections.remove(section)

            tableView.deleteRows(at: viewModel.indexPaths(for: section), with: .none)
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }
}

private extension UIBarButtonItem {
    static var appIconBarButton: UIBarButtonItem {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.stormbirdToken()
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.anchorsConstraint(to: container)
        ])

        return UIBarButtonItem(customView: container)
    }
}
