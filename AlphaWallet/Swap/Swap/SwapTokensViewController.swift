//
//  SwapTokensViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit
import Combine
import BigInt
import AlphaWalletFoundation

protocol SwapTokensViewControllerDelegate: class {
    func swapSelected(in viewController: SwapTokensViewController)
    func changeSwapRouteSelected(in viewController: SwapTokensViewController)
    func chooseTokenSelected(in viewController: SwapTokensViewController, selection: SwapTokens.TokenSelection)
    func didClose(in viewController: SwapTokensViewController)
}

class SwapTokensViewController: UIViewController {
    private let fromTokenHeaderView = SendViewSectionHeader()
    private let toTokenHeaderView = SendViewSectionHeader()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private lazy var fromAmountTextField: AmountTextField_v2 = {
        let amountTextField = AmountTextField_v2(token: viewModel.swapPair.value.from, debugName: "from")
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        amountTextField.viewModel.accessoryButtonTitle = .next
        amountTextField.viewModel.errorState = .none
        amountTextField.isAlternativeAmountEnabled = true
        amountTextField.allFundsAvailable = true

        return amountTextField
    }()
    private lazy var toAmountTextField: AmountTextField_v2 = {
        let amountTextField = AmountTextField_v2(token: viewModel.swapPair.value.to, debugName: "to")
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.viewModel.accessoryButtonTitle = .next
        amountTextField.viewModel.errorState = .none
        amountTextField.isAlternativeAmountEnabled = true
        amountTextField.allFundsAvailable = false
        amountTextField.textField.isUserInteractionEnabled = false

        return amountTextField
    }()
    private lazy var quoteDetailsView: SwapQuoteDetailsView = {
        let view = SwapQuoteDetailsView(viewModel: viewModel.quoteDetailsViewModel)
        view.delegate = self

        return view
    }()
    private lazy var togglePairButton: UIButton = {
        let imageView = UIButton(type: .system)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setImage(R.image.iconsSystemSwitch2(), for: .normal)

        NSLayoutConstraint.activate(imageView.sized(.init(width: 24, height: 24)))

        return imageView
    }()
    private lazy var containerView: ScrollableStackView = ScrollableStackView()
    private let line: UIView = .spacer(height: 1, backgroundColor: R.color.mercury()!)
    private lazy var footerBar: ButtonsBarBackgroundView = {
        let view = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: .zero, separatorHeight: 1.0)
        return view
    }()
    private (set) var loadingIndicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.hidesWhenStopped = true

        return view
    }()
    private var cancelable = Set<AnyCancellable>()
    private let viewModel: SwapTokensViewModel
    private lazy var checker = KeyboardChecker(self, resetHeightDefaultValue: 0)
    private var footerBottomConstraint: NSLayoutConstraint!

    weak var delegate: SwapTokensViewControllerDelegate?

    init(viewModel: SwapTokensViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        generageLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure()
        let continueButton = buttonsBar.buttons[0]
        continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        continueButton.addTarget(self, action: #selector(swapTokensSelected), for: .touchUpInside)
        toAmountTextField.selectCurrencyButton.addTarget(self, action: #selector(chooseTokenSelected), for: .touchUpInside)
        fromAmountTextField.selectCurrencyButton.addTarget(self, action: #selector(chooseTokenSelected), for: .touchUpInside)

        bind(viewModel: viewModel)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checker.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        checker.viewWillDisappear()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func generageLayout() {
        containerView.stackView.addArrangedSubviews([
            fromTokenHeaderView,
            fromAmountTextField.defaultLayout(edgeInsets: .init(top: 0, left: 16, bottom: 0, right: 16)),
            line,
            toTokenHeaderView,
            toAmountTextField.defaultLayout(edgeInsets: .init(top: 0, left: 16, bottom: 0, right: 16)),
            .spacer(height: 1, backgroundColor: R.color.mercury()!),
            quoteDetailsView
        ])

        view.addSubview(footerBar)
        view.addSubview(containerView)
        view.addSubview(togglePairButton)

        footerBottomConstraint = footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            togglePairButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            togglePairButton.centerYAnchor.constraint(equalTo: line.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBottomConstraint,
        ])

        checker.constraints = [footerBottomConstraint]
    }

    private func bind(viewModel: SwapTokensViewModel) {
        view.backgroundColor = viewModel.backgoundColor
        containerView.scrollView.backgroundColor = viewModel.backgoundColor
        title = viewModel.title

        fromTokenHeaderView.configure(viewModel: viewModel.fromHeaderViewModel)
        toTokenHeaderView.configure(viewModel: viewModel.toHeaderViewModel)

        let allFunds = fromAmountTextField.allFundsButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher()
        let togglePair = togglePairButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher()
        let input = SwapTokensViewModelInput(cryptoValue: fromAmountTextField.cryptoValue, allFunds: allFunds, togglePair: togglePair)
        let output = viewModel.transform(input: input)

        output.anyErrorString
            .sink { [weak self] in self?.displayError(message: $0) }
            .store(in: &cancelable)

        output.isContinueButtonEnabled
            .assign(to: \.isEnabled, on: buttonsBar.buttons[0])
            .store(in: &cancelable)

        output.isConfiguratorInUpdatingState
            .sink { [weak loadingIndicatorView] isLoading in
                if isLoading {
                    loadingIndicatorView?.startAnimating()
                } else {
                    loadingIndicatorView?.stopAnimating()
                }
            }.store(in: &cancelable)

        output.convertedValue
            .sink { [weak toAmountTextField] in toAmountTextField?.set(crypto: $0, useFormatting: false) }
            .store(in: &cancelable)

        output.amountValidation
            .sink { [weak fromAmountTextField] in fromAmountTextField?.viewModel.errorState = $0 }
            .store(in: &cancelable)

        output.tokens
            .sink { [weak fromAmountTextField, weak toAmountTextField] tokens in
                fromAmountTextField?.viewModel.set(token: tokens.from)
                toAmountTextField?.viewModel.set(token: tokens.to)
            }.store(in: &cancelable)

        output.fromTokenBalance
            .sink { [weak fromAmountTextField] in fromAmountTextField?.statusLabel.text = $0 }
            .store(in: &cancelable)

        output.toTokenBalance
            .sink { [weak toAmountTextField] in toAmountTextField?.statusLabel.text = $0 }
            .store(in: &cancelable)

        output.allFunds.sink { [weak fromAmountTextField] in fromAmountTextField?.set(crypto: $0.allFundsFullValue.localizedString, shortCrypto: $0.allFundsShortValue, useFormatting: false) }
            .store(in: &cancelable)
    }

    @objc private func chooseTokenSelected(_ sender: UIButton) {
        let isFromActionButton = sender == fromAmountTextField.selectCurrencyButton.actionButton
        delegate?.chooseTokenSelected(in: self, selection: isFromActionButton ? .from : .to)
    }

    @objc private func swapTokensSelected(_ sender: UIButton) {
        view.endEditing(true)
        delegate?.swapSelected(in: self)
    }
}

extension SwapTokensViewController: SwapQuoteDetailsViewDelegate {
    func changeSwapRouteSelected(in view: SwapQuoteDetailsView) {
        delegate?.changeSwapRouteSelected(in: self)
    }
}

extension SwapTokensViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension SwapTokensViewController: AmountTextField_v2Delegate {

    func changeAmount(in textField: AmountTextField_v2) {
        //no-op
    }

    func changeType(in textField: AmountTextField_v2) {
        //no-op
    }

    func shouldReturn(in textField: AmountTextField_v2) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
