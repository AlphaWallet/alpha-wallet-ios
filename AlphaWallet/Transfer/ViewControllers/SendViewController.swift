// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import JSONRPCKit
import APIKit
import QRCodeReaderViewController
import BigInt
import TrustKeystore
import MBProgressHUD

protocol SendViewControllerDelegate: class, CanOpenURL {
    func didPressConfirm(
            transaction: UnconfirmedTransaction,
            transferType: TransferType,
            in viewController: SendViewController
    )
}

class SendViewController: UIViewController, CanScanQRCode {
    private let roundedBackground = RoundedBackground()
    private let header = SendHeaderView()
    private let amountTextField = AmountTextField()
    private let targetAddressLabel = UILabel()
    private let amountLabel = UILabel()
    private let nextButton = UIButton(type: .system)
    private var viewModel: SendViewModel!
    private var headerViewModel = SendHeaderViewViewModel()
    private var balanceViewModel: BalanceBaseViewModel?
    private let session: WalletSession
    private let account: Account
    private let ethPrice: Subscribable<Double>
    private var gasPrice: BigInt?
    private var data = Data()
    private lazy var decimalFormatter: DecimalFormatter = {
        return DecimalFormatter()
    }()

    let targetAddressTextField = AddressTextField()
    weak var delegate: SendViewControllerDelegate?
    let config: Config
    var contract: String {
        switch transferType {
        case .ERC20Token(let token):
            return token.contract
        case .ether:
            return account.address.eip55String
        case .dapp:
            return "0x"
        case .ERC875Token:
            return "0x"
        case .ERC875TokenOrder:
            return "0x"
        case .ERC721Token:
            return "0x"
        }
    }
    let transferType: TransferType
    let storage: TokensDataStore

    init(
            session: WalletSession,
            storage: TokensDataStore,
            account: Account,
            transferType: TransferType = .ether(config: Config(), destination: .none),
            ethPrice: Subscribable<Double>
    ) {
        self.session = session
        self.account = account
        self.transferType = transferType
        self.storage = storage
        self.ethPrice = ethPrice
        self.config = Config()

        super.init(nibName: nil, bundle: nil)

        configureBalanceViewModel()

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .next

        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        switch transferType {
        case .ether:
            ethPrice.subscribe { [weak self] value in
                if let value = value {
                    self?.amountTextField.ethToDollarRate = value
                }
            }
        default:
            amountTextField.alternativeAmountLabel.isHidden = true
            amountTextField.isFiatButtonHidden = true
        }

        nextButton.setTitle(R.string.localizable.send(), for: .normal)
        nextButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        let buttonsStackView = [nextButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            header,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 7: 20),
            targetAddressLabel,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 2 : 4),
            targetAddressTextField,
            targetAddressTextField.ensAddressLabel,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 7 : 14),
            amountLabel,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 2 : 4),
            amountTextField,
            amountTextField.alternativeAmountLabel,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = Metrics.greenButtonHeight
        footerBar.addSubview(buttonsStackView)
        
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            header.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),

            targetAddressTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            targetAddressTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),

            amountTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            amountTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),
            amountTextField.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen() ? 30 : 50),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        storage.updatePrices()
        getGasPrice()
    }

    @objc func closeKeyboard() {
        view.endEditing(true)
    }

    func configure(viewModel: SendViewModel) {
        self.viewModel = viewModel

        targetAddressTextField.configureOnce()

        view.backgroundColor = viewModel.backgroundColor

        headerViewModel.showAlternativeAmount = viewModel.showAlternativeAmount
        header.configure(viewModel: headerViewModel)

        targetAddressLabel.font = viewModel.textFieldsLabelFont
        targetAddressLabel.textColor = viewModel.textFieldsLabelTextColor

        amountLabel.font = viewModel.textFieldsLabelFont
        amountLabel.textColor = viewModel.textFieldsLabelTextColor

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        roundCornersBasedOnHeight()
    }

    private func roundCornersBasedOnHeight() {
        amountTextField.layer.cornerRadius = amountTextField.frame.size.height / 2
    }

    func getGasPrice() {
        let request = EtherServiceRequest(batch: BatchFactory().create(GasPriceRequest()))
        Session.send(request) { [weak self] result in
            switch result {
            case .success(let balance):
                self?.gasPrice = BigInt(balance.drop0x, radix: 16)
            case .failure: break
            }
        }
    }

    @objc func send() {
        let input = targetAddressTextField.value
        guard let address = Address(string: input) else {
            return displayError(error: Errors.invalidAddress)
        }
        let amountString = amountTextField.ethCost
        let parsedValue: BigInt? = {
            switch transferType {
            case .ether, .dapp:
                return EtherNumberFormatter.full.number(from: amountString, units: .ether)
            case .ERC20Token(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .ERC875Token(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .ERC875TokenOrder(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .ERC721Token(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            }
        }()
        guard let value = parsedValue else {
            return displayError(error: SendInputErrors.wrongInput)
        }

        if case .ether = transferType, let balance = session.balance, balance.value < value {
            return displayError(title: R.string.localizable.aSendBalanceInsufficient(), error: Errors.invalidAmount)
        }

        let transaction = UnconfirmedTransaction(
                transferType: transferType,
                value: value,
                to: address,
                data: data,
                gasLimit: .none,
                tokenId: .none,
                gasPrice: gasPrice,
                nonce: .none,
                v: .none,
                r: .none,
                s: .none,
                expiry: .none,
                indices: .none,
                tokenIds: .none
        )
        delegate?.didPressConfirm(transaction: transaction, transferType: transferType, in: self)
    }

    func activateAmountView() {
        _ = amountTextField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureBalanceViewModel() {
        switch transferType {
        case .ether:
            session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self, let viewModel = viewModel else { return }
                let amount = viewModel.amountShort
                celf.headerViewModel.title = "\(amount) \(celf.session.config.server.name) (\(viewModel.symbol))"
                let etherToken = TokensDataStore.etherToken(for: celf.session.config)
                let ticker = celf.storage.coinTicker(for: etherToken)
                celf.headerViewModel.ticker = ticker
                celf.headerViewModel.currencyAmount = celf.session.balanceCoordinator.viewModel.currencyAmount
                celf.headerViewModel.currencyAmountWithoutSymbol = celf.session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
                if let viewModel = celf.viewModel {
                    celf.configure(viewModel: viewModel)
                }
            }
            session.refresh(.ethBalance)
        case .ERC20Token(let token):
            let viewModel = BalanceTokenViewModel(token: token)
            let amount = viewModel.amountShort
            headerViewModel.title = "\(amount) \(viewModel.symbol)"
            let etherToken = TokensDataStore.etherToken(for: session.config)
            let ticker = storage.coinTicker(for: etherToken)
            headerViewModel.ticker = ticker
            headerViewModel.currencyAmount = session.balanceCoordinator.viewModel.currencyAmount
            headerViewModel.currencyAmountWithoutSymbol = session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
            if let viewModel = self.viewModel {
                configure(viewModel: viewModel)
            }
        default:
            break
        }
    }
}

extension SendViewController: QRCodeReaderDelegate {
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        reader.dismiss(animated: true) { [weak self] in
            self?.activateAmountView()
        }

        guard let result = QRURLParser.from(string: result) else {
            return
        }
        targetAddressTextField.value = result.address

        if let dataString = result.params["data"] {
            data = Data(hex: dataString.drop0x)
        } else {
            data = Data()
        }

        if let value = result.params["amount"] {
            amountTextField.ethCost = EtherNumberFormatter.full.string(from: BigInt(value) ?? BigInt(), units: .ether)
        } else {
            amountTextField.ethCost = ""
        }
    }
}

extension SendViewController: AmountTextFieldDelegate {
    func changeAmount(in textField: AmountTextField) {
        //do nothing
    }

    func changeType(in textField: AmountTextField) {
        //do nothing
    }
}

extension SendViewController: AddressTextFieldDelegate {
    func displayError(error: Error, for textField: AddressTextField) {
        displayError(error: error)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            promptUserOpenSettingsToChangeCameraPermission()
            return
        }
        let controller = QRCodeReaderViewController()
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }

    func didPaste(in textField: AddressTextField) {
        activateAmountView()
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        activateAmountView()
        return true
    }

    func didChange(to string: String, in textField: AddressTextField) {
    }
}
