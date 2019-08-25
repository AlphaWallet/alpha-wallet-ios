// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import JSONRPCKit
import APIKit
import QRCodeReaderViewController
import BigInt
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
    private let scrollView = UIScrollView()
    private let header = SendHeaderViewWithIntroduction()
    private let targetAddressLabel = UILabel()
    private let amountLabel = UILabel()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
    private var viewModel: SendViewModel!
    lazy private var headerViewModel = SendHeaderViewViewModelWithIntroduction(server: session.server, assetDefinitionStore: assetDefinitionStore)
    private var balanceViewModel: BalanceBaseViewModel?
    private let session: WalletSession
    private let account: EthereumAccount
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private var gasPrice: BigInt?
    private var data = Data()
    private lazy var decimalFormatter: DecimalFormatter = {
        return DecimalFormatter()
    }()
    let targetAddressTextField = AddressTextField()
    lazy var amountTextField = AmountTextField(server: session.server)
    weak var delegate: SendViewControllerDelegate?
    let transferType: TransferType
    let storage: TokensDataStore

    init(
            session: WalletSession,
            storage: TokensDataStore,
            account: EthereumAccount,
            transferType: TransferType,
            cryptoPrice: Subscribable<Double>,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.session = session
        self.account = account
        self.transferType = transferType
        self.storage = storage
        self.ethPrice = cryptoPrice
        self.assetDefinitionStore = assetDefinitionStore

        super.init(nibName: nil, bundle: nil)

        configureBalanceViewModel()

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .next

        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        switch transferType {
        case .nativeCryptocurrency:
            cryptoPrice.subscribe { [weak self] value in
                if let value = value {
                    self?.amountTextField.cryptoToDollarRate = value
                }
            }
        case .ERC20Token, .ERC875Token, .ERC875TokenOrder, .ERC721Token, .dapp:
            amountTextField.alternativeAmountLabel.isHidden = true
            amountTextField.isFiatButtonHidden = true
        }

        let stackView = [
            header,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 20),
            targetAddressLabel,
            .spacer(height: ScreenChecker().isNarrowScreen ? 2 : 4),
            targetAddressTextField,
            targetAddressTextField.ensAddressLabel,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7 : 14),
            amountLabel,
            .spacer(height: ScreenChecker().isNarrowScreen ? 2 : 4),
            amountTextField,
            amountTextField.alternativeAmountLabel,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            header.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),

            targetAddressTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            targetAddressTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),

            amountTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            amountTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),
            amountTextField.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 30 : 50),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
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

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
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

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.send(), for: .normal)
        nextButton.addTarget(self, action: #selector(send), for: .touchUpInside)
    }

    func getGasPrice() {
        let request = EtherServiceRequest(server: session.server, batch: BatchFactory().create(GasPriceRequest()))
        Session.send(request) { [weak self] result in
            switch result {
            case .success(let balance):
                self?.gasPrice = BigInt(balance.drop0x, radix: 16)
            case .failure: break
            }
        }
    }

    @objc func send() {
        let input = targetAddressTextField.value.trimmed
        guard let address = AlphaWallet.Address(string: input) else { return displayError(error: Errors.invalidAddress) }
        let amountString = amountTextField.ethCost
        let parsedValue: BigInt? = {
            switch transferType {
            case .nativeCryptocurrency, .dapp:
                return EtherNumberFormatter.full.number(from: amountString, units: .ether)
            case .ERC20Token(let token, _, _):
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

        if case .nativeCryptocurrency = transferType, let balance = session.balance, balance.value < value {
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
        case .nativeCryptocurrency:
            session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self, let viewModel = viewModel else { return }
                let amount = viewModel.amountShort
                celf.headerViewModel.title = "\(amount) \(celf.session.server.name) (\(viewModel.symbol))"
                let etherToken = TokensDataStore.etherToken(forServer: celf.session.server)
                let ticker = celf.storage.coinTicker(for: etherToken)
                celf.headerViewModel.ticker = ticker
                celf.headerViewModel.currencyAmount = celf.session.balanceCoordinator.viewModel.currencyAmount
                celf.headerViewModel.currencyAmountWithoutSymbol = celf.session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
                if let viewModel = celf.viewModel {
                    celf.configure(viewModel: viewModel)
                }
            }
            session.refresh(.ethBalance)
        case .ERC20Token(let token, _, _):
            let viewModel = BalanceTokenViewModel(token: token)
            let amount = viewModel.amountShort
            headerViewModel.title = "\(amount) \(viewModel.name) (\(viewModel.symbol))"
            let etherToken = TokensDataStore.etherToken(forServer: session.server)
            let ticker = storage.coinTicker(for: etherToken)
            headerViewModel.ticker = ticker
            headerViewModel.currencyAmount = session.balanceCoordinator.viewModel.currencyAmount
            headerViewModel.currencyAmountWithoutSymbol = session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol

            //TODO is this the best place to put it? because this func is called configureBalanceViewModel() "balance"
            headerViewModel.contractAddress = token.contractAddress

            if let viewModel = self.viewModel {
                configure(viewModel: viewModel)
            }
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .dapp:
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
        guard let result = QRURLParser.from(string: result) else { return }
        guard checkAndFillEIP861Details(result: result) else { return }
    }

    func checkAndFillEIP861Details(result: ParserResult) -> Bool {
        //TODO error display on returns
        //Note: not checking the 'transferType' since erc20 is implied by whether it has uint256 and address.
        //The contract address can be compared to the one in the token card and if it matches will proceed else fail
        //this protects the user from sending funds to the wrong address
        if let chainId = result.params["chainId"] {
            guard self.session.server.chainID == Int(chainId) else { return false }
        }
        //if erc20 (eip861 qr code)
        if let recipient = result.params["address"], let amt = result.params["uint256"] {
            guard recipient != "0" && amt != "0" else { return false }
            //address will be set as contract address if erc token, therefore need to ensure the QR code has set the same contract address
            //as the user is using
            guard transferType.contract.sameContract(as: result.address) else { return false }
            amountTextField.ethCost = EtherNumberFormatter.full.string(from: BigInt(amt) ?? BigInt(), units: .ether)
            targetAddressTextField.value = recipient
            return true
        } else {
            targetAddressTextField.value = result.address.eip55String
        }
        //if ether transfer (eip861 qr code)
        if let value = result.params["value"], let amountToSend = Double(value) {
            guard value != "0" else { return false }
            amountTextField.ethCost = EtherNumberFormatter.full.string(from: BigInt(amountToSend), units: .ether)
        } else {
            amountTextField.ethCost = ""
        }
        return true
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
        let controller = QRCodeReaderViewController(cancelButtonTitle: nil, chooseFromPhotoLibraryButtonTitle: R.string.localizable.photos())
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
