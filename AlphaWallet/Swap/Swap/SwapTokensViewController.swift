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

protocol SwapTokensViewControllerDelegate: AnyObject {
    func swapSelected(in viewController: SwapTokensViewController)
    func changeSwapRouteSelected(in viewController: SwapTokensViewController)
    func chooseTokenSelected(in viewController: SwapTokensViewController, selection: SwapTokens.TokenSelection)
    func didClose(in viewController: SwapTokensViewController)
}

class SwapTokensViewController: UIViewController {
    private let fromTokenHeaderView = SendViewSectionHeader()
    private let toTokenHeaderView = SendViewSectionHeader()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private lazy var fromAmountTextField: AmountTextField = {
        let amountTextField = AmountTextField(token: viewModel.swapPair.value.from, debugName: "from", tokenImageFetcher: tokenImageFetcher)
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        amountTextField.inputAccessoryButtonType = .done
        amountTextField.viewModel.errorState = .none
        amountTextField.isAlternativeAmountEnabled = true
        amountTextField.isAllFundsEnabled = true

        return amountTextField
    }()
    private lazy var toAmountTextField: AmountTextField = {
        let amountTextField = AmountTextField(token: viewModel.swapPair.value.to, debugName: "to", tokenImageFetcher: tokenImageFetcher)
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.inputAccessoryButtonType = .none
        amountTextField.viewModel.errorState = .none
        amountTextField.isAlternativeAmountEnabled = true
        amountTextField.isAllFundsEnabled = false
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
    private let line: UIView = .separator()
    private lazy var footerBar: ButtonsBarBackgroundView = {
        let view = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
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
    private let tokenImageFetcher: TokenImageFetcher

    weak var delegate: SwapTokensViewControllerDelegate?

    init(viewModel: SwapTokensViewModel,
         tokenImageFetcher: TokenImageFetcher) {

        self.viewModel = viewModel
        self.tokenImageFetcher = tokenImageFetcher
        super.init(nibName: nil, bundle: nil)

        containerView.stackView.addArrangedSubviews([
            fromTokenHeaderView,
            fromAmountTextField.defaultLayout(edgeInsets: .init(top: ScreenChecker.size(big: 16, medium: 16, small: 7), left: 16, bottom: 0, right: 16)),
            line,
            toTokenHeaderView,
            toAmountTextField.defaultLayout(edgeInsets: .init(top: ScreenChecker.size(big: 16, medium: 16, small: 7), left: 16, bottom: 0, right: 16)),
            UIView.separator(),
            quoteDetailsView
        ])

        view.addSubview(footerBar)
        view.addSubview(containerView)
        view.addSubview(togglePairButton)

        NSLayoutConstraint.activate([
            togglePairButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            togglePairButton.centerYAnchor.constraint(equalTo: line.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure()
        let continueButton = buttonsBar.buttons[0]
        continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        continueButton.addTarget(self, action: #selector(swapTokensSelected), for: .touchUpInside)
        toAmountTextField.selectCurrencyButton.addTarget(self, action: #selector(chooseTokenSelected), for: .touchUpInside)
        fromAmountTextField.selectCurrencyButton.addTarget(self, action: #selector(chooseTokenSelected), for: .touchUpInside)

        containerView.backgroundColor = Configuration.Color.Semantic.tableViewHeaderBackground
        view.backgroundColor = Configuration.Color.Semantic.tableViewHeaderBackground
        title = viewModel.title
        fromTokenHeaderView.configure(viewModel: viewModel.fromHeaderViewModel)
        toTokenHeaderView.configure(viewModel: viewModel.toHeaderViewModel)

        bind(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func bind(viewModel: SwapTokensViewModel) {
        let input = SwapTokensViewModelInput(
            cryptoValue: fromAmountTextField.cryptoValuePublisher,
            allFunds: fromAmountTextField.allFundsButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher(),
            togglePair: togglePairButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher())

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
            .sink { [weak toAmountTextField] in toAmountTextField?.set(amount: $0) }
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

        output.allFunds
            .sink { [weak fromAmountTextField] in fromAmountTextField?.set(amount: $0) }
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

extension SwapTokensViewController: AmountTextFieldDelegate {
    func doneButtonTapped(for textField: AmountTextField) {
        view.endEditing(true)
    }
    
    func shouldReturn(in textField: AmountTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
