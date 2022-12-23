// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import SafariServices
import AlphaWalletFoundation
import Combine

protocol TransactionDetailsViewControllerDelegate: AnyObject, CanOpenURL {
    func didSelectShare(in viewController: TransactionDetailsViewController, item: URL, sender: UIBarButtonItem)
}

class TransactionDetailsViewController: UIViewController {
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        view.stackView.spacing = 10

        return view
    }()
    private let viewModel: TransactionDetailsViewModel
    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .secondary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()
    private let transactionId = TransactionFieldView.textLabelView(title: R.string.localizable.transactionIdLabelTitle(), icon: R.image.copy())
    private let from = TransactionFieldView.textLabelView(title: R.string.localizable.transactionFromLabelTitle(), icon: R.image.copy())
    private let to = TransactionFieldView.textLabelView(title: R.string.localizable.transactionToLabelTitle(), icon: R.image.copy())
    private let gasFee = TransactionFieldView.textLabelView(title: R.string.localizable.transactionGasFeeLabelTitle())
    private let confirmation = TransactionFieldView.textLabelView(title: R.string.localizable.transactionConfirmationLabelTitle())
    private let createdAt = TransactionFieldView.textLabelView(title: R.string.localizable.transactionTimeLabelTitle())
    private let blockNumber = TransactionFieldView.textLabelView(title: R.string.localizable.transactionBlockNumberLabelTitle())
    private let nonce = TransactionFieldView.textLabelView(title: R.string.localizable.transactionNonceLabelTitle())
    private let amount = TransactionFieldView.textLabelView(title: R.string.localizable.transactionAmountLabelTitle())
    private lazy var network = TransactionFieldView.iconView(title: R.string.localizable.transactionNetworkLabelTitle(), server: viewModel.server)
    private let header = TransactionHeaderView()
    private lazy var footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0.0)
    private var moreButton: UIButton { buttonsBar.buttons[0] }
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: TransactionDetailsViewControllerDelegate?

    init(viewModel: TransactionDetailsViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        containerView.stackView.addArrangedSubviews([
            header,
            .spacer(height: 10),
            amount,
            from,
            to,
            network,
            gasFee,
            confirmation,
            transactionId,
            createdAt,
            blockNumber,
            nonce
        ])

        let stackView = [containerView, footerBar].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsIgnoringBottomSafeArea(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if viewModel.shareAvailable {
            navigationItem.rightBarButtonItem = UIBarButtonItem.actionBarButton(self, selector: #selector(shareButtonSelected))
        }
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: TransactionDetailsViewModel) {
        let copyToClipboard = Publishers.Merge3(
            to.addTapPublisher().map { _ in TransactionDetailsViewModel.CopyableField.to },
            from.addTapPublisher().map { _ in TransactionDetailsViewModel.CopyableField.from },
            transactionId.addTapPublisher().map { _ in TransactionDetailsViewModel.CopyableField.transactionId }
        ).eraseToAnyPublisher()

        let input = TransactionDetailsViewModelInput(
            openUrl: moreButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher(),
            copyToClipboard: copyToClipboard)
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self, navigationItem] viewState in
                navigationItem.title = viewState.title

                self?.header.configure(viewModel: viewState.header)
                self?.amount.configure(attributedValueText: viewState.header.amount)
                self?.from.configure(value: viewState.from)
                self?.to.configure(value: viewState.to)
                self?.gasFee.configure(value: viewState.gasFee)
                self?.confirmation.configure(value: viewState.confirmation)
                self?.transactionId.configure(value: viewState.transactionId)
                self?.createdAt.configure(value: viewState.createdAt)
                self?.blockNumber.configure(value: viewState.blockNumber)
                self?.nonce.configure(value: viewState.nonce)
                self?.network.configure(server: viewState.server)
                self?.moreButton.setTitle(viewState.moreButtonTitle, for: .normal)
                self?.footerBar.isHidden = viewState.barIsHidden
            }.store(in: &cancelable)

        output.copiedToClipboard
            .sink(receiveValue: { [weak self] in self?.view.showCopiedToClipboard(title: $0) })
            .store(in: &cancelable)

        output.openUrl
            .sink(receiveValue: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didPressOpenWebPage($0, in: strongSelf)
            }).store(in: &cancelable)
    }

    @objc private func shareButtonSelected(_ sender: UIBarButtonItem) {
        guard let item = viewModel.shareItem else { return }
        delegate?.didSelectShare(in: self, item: item, sender: sender)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}
