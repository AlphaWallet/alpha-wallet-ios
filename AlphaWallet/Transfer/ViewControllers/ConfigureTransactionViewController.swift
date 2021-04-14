// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

protocol ConfigureTransactionViewControllerDelegate: class {
    func didSavedToUseDefaultConfigurationType(_ configurationType: TransactionConfigurationType, in viewController: ConfigureTransactionViewController)
    func didSaved(customConfiguration: TransactionConfiguration, in viewController: ConfigureTransactionViewController)
}

class ConfigureTransactionViewController: UIViewController {
    private struct EditCell {
        let gasLimit = SliderTableViewCell(style: .default, reuseIdentifier: nil)
        let nonce = TextFieldTableViewCell(style: .default, reuseIdentifier: nil)
        let totalFee = TextFieldTableViewCell(style: .default, reuseIdentifier: nil)
        let data = TextFieldTableViewCell(style: .default, reuseIdentifier: nil)
        let gasPrice = SliderTableViewCell(style: .default, reuseIdentifier: nil)
    }

    private let cells = EditCell()
    private var viewModel: ConfigureTransactionViewModel
    private let notificationCenter = NotificationCenter.default
    private var lastSavedConfiguration: TransactionConfiguration
    weak var delegate: ConfigureTransactionViewControllerDelegate?

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(GasSpeedTableViewCell.self)
        tableView.registerHeaderFooterView(GasSpeedTableViewHeaderView.self)
        tableView.tableFooterView = createTableFooter()
        tableView.separatorStyle = .none
        tableView.allowsSelection = true
        return tableView
    }()

    override func loadView() {
        view = tableView
    }

    init(viewModel: ConfigureTransactionViewModel) {
        self.viewModel = viewModel
        self.lastSavedConfiguration = viewModel.configurationToEdit.configuration

        super.init(nibName: nil, bundle: nil)

        navigationItem.title = viewModel.title
        tableView.backgroundColor = viewModel.backgroundColor
        navigationItem.rightBarButtonItem = UIBarButtonItem.saveBarButton(self, selector: #selector(saveButtonSelected))

        handleRecovery()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        notificationCenter.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        notificationCenter.removeObserver(self)

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        recalculateTotalFeeForCustomGas()
    }

    private func handleRecovery() {
        switch viewModel.recoveryMode {
        case .invalidNonce:
            cells.nonce.textField.status = .error(ConfigureTransactionError.leaveNonceEmpty.localizedDescription)
        case .none:
            break
        }
    }

    func configure(viewModel: ConfigureTransactionViewModel) {
        self.viewModel = viewModel
        recalculateTotalFeeForCustomGas()
        tableView.reloadData()
    }

    func configure(withEstimatedGasLimit value: BigInt) {
        var updatedViewModel = viewModel
        var configuration = makeConfigureSuitableForSaving(from: updatedViewModel.configurationToEdit.configuration)
        guard configuration.gasLimit != value else { return }
        configuration.setEstimated(gasLimit: value)
        updatedViewModel.configurationToEdit = EditedTransactionConfiguration(configuration: configuration)
        viewModel = updatedViewModel
        recalculateTotalFeeForCustomGas()
        tableView.reloadData()
    }

    func configure(withEstimatedGasPrice value: BigInt, configurator: TransactionConfigurator) {
        var updatedViewModel = viewModel
        var configuration = makeConfigureSuitableForSaving(from: updatedViewModel.configurationToEdit.configuration)
        guard configuration.gasPrice != value else { return }
        configuration.setEstimated(gasPrice: value)
        updatedViewModel.configurationToEdit = EditedTransactionConfiguration(configuration: configuration)
        updatedViewModel.configurations = configurator.configurations
        viewModel = updatedViewModel
        recalculateTotalFeeForCustomGas()
        showGasPriceWarning()
        tableView.tableFooterView = createTableFooter()
        tableView.reloadData()
    }

    func configure(nonce: Int, configurator: TransactionConfigurator) {
        var updatedViewModel = viewModel
        var configuration = makeConfigureSuitableForSaving(from: updatedViewModel.configurationToEdit.configuration)
        guard configuration.nonce != nonce else { return }
        configuration.set(nonce: nonce)
        updatedViewModel.configurationToEdit = EditedTransactionConfiguration(configuration: configuration)
        updatedViewModel.configurations = configurator.configurations
        viewModel = updatedViewModel
        recalculateTotalFeeForCustomGas()
        tableView.reloadData()
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo else {
            return
        }

        let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let curve = UIView.AnimationCurve(rawValue: (info[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber).intValue)!
        let bottom = endFrame.height - UIApplication.shared.bottomSafeAreaHeight

        UIView.setAnimationCurve(curve)
        UIView.animate(withDuration: duration, animations: {
            self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
            self.tableView.scrollIndicatorInsets = self.tableView.contentInset
        }, completion: { _ in

        })
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = notification.userInfo else {
            return
        }

        let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let curve = UIView.AnimationCurve(rawValue: (info[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber).intValue)!

        UIView.setAnimationCurve(curve)
        UIView.animate(withDuration: duration, animations: {
            self.tableView.contentInset = .zero
            self.tableView.scrollIndicatorInsets = self.tableView.contentInset
        }, completion: { _ in

        })
    }

    private func createTableFooter() -> UIView {
        if let gasPriceWarning = viewModel.gasPriceWarning {
            return createTableFooterForGasPriceWarning(gasPriceWarning)
        } else {
            return createTableFooterForGasInformation()
        }
    }

    private func createTableFooterForGasInformation() -> UIView {
        let footer = UIView(frame: .init(x: 0, y: 0, width: 0, height: 100))
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = Fonts.regular(size: 15)
        label.textColor = R.color.dove()
        label.text = R.string.localizable.transactionConfirmationFeeFooterText()
        footer.addSubview(label)
        NSLayoutConstraint.activate([
            label.anchorsConstraint(to: footer, edgeInsets: UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32)),
        ])
        return footer
    }

    private func createTableFooterForGasPriceWarning(_ gasPriceWarning: TransactionConfigurator.GasPriceWarning) -> UIView {
        let footer = UIView(frame: .init(x: 0, y: 0, width: 0, height: 0))

        let background = UIView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = .init(red: 255, green: 235, blue: 234)
        background.borderColor = .init(red: 252, green: 187, blue: 183)
        background.cornerRadius = 8
        background.borderWidth = 1
        footer.addSubview(background)

        let warningIcon = UIImageView(image: R.image.gasWarning())
        warningIcon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.textAlignment = .center
        titleLabel.font = Fonts.semibold(size: 20)
        titleLabel.textColor = R.color.danger()
        titleLabel.text = gasPriceWarning.longTitle

        let descriptionLabel = UITextView()
        descriptionLabel.backgroundColor = .clear
        descriptionLabel.textColor = R.color.dove()
        descriptionLabel.textAlignment = .center
        descriptionLabel.isEditable = false
        descriptionLabel.isSelectable = true
        descriptionLabel.isUserInteractionEnabled = true
        descriptionLabel.isScrollEnabled = false
        descriptionLabel.dataDetectorTypes = .link
        descriptionLabel.font = Fonts.regular(size: 15)
        descriptionLabel.text = gasPriceWarning.description

        let row0 = [warningIcon, titleLabel].asStackView(axis: .horizontal, spacing: 6)
        let row1 = descriptionLabel

        let stackView = [
            row0,
            row1,
        ].asStackView(axis: .vertical, spacing: 6, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(stackView)

        NSLayoutConstraint.activate([
            background.anchorsConstraint(to: footer, margin: 16),

            stackView.anchorsConstraint(to: background, edgeInsets: UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 16)),

            warningIcon.widthAnchor.constraint(equalToConstant: 24),
            warningIcon.widthAnchor.constraint(equalTo: warningIcon.heightAnchor),

            descriptionLabel.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -50),

            descriptionLabel.widthAnchor.constraint(equalToConstant: 250),
        ])

        var frame = footer.frame
        frame.size.height = footer.systemLayoutSizeFitting(footer.frame.size).height
        footer.frame = frame

        return footer
    }

    private func recalculateTotalFeeForCustomGas() {
        cells.totalFee.value = viewModel.gasViewModel.feeText
        let configurationTypes = viewModel.configurationTypes
        if let indexPath = configurationTypes.index(of: .custom).flatMap({ IndexPath(row: $0, section: ConfigureTransactionViewModel.Section.configurationTypes.rawValue) }), let cell = tableView.cellForRow(at: indexPath) as? GasSpeedTableViewCell {
            cell.configure(viewModel: viewModel.gasSpeedViewModel(indexPath: indexPath))
        }
        showGasPriceWarning()
        showGasLimitWarning()
        showGasFeeWarning()
        tableView.tableFooterView = createTableFooter()
    }

    private func showGasPriceWarning() {
        if viewModel.gasPriceWarning == nil {
            cells.gasPrice.textField.status = .none
        } else {
            cells.gasPrice.textField.status = .error("")
        }
    }

    private func showGasLimitWarning() {
        if let warning = viewModel.gasLimitWarning {
            cells.gasLimit.textField.status = .error(warning.description)
        } else {
            cells.gasLimit.textField.status = .none
        }
        refreshCellsWithoutAnimation()
    }

    private func showGasFeeWarning() {
        if let warning = viewModel.gasFeeWarning {
            cells.totalFee.textField.status = .error(warning.description)
        } else {
            cells.totalFee.textField.status = .none
        }
        refreshCellsWithoutAnimation()
    }

    private func refreshCellsWithoutAnimation() {
        //async needed otherwise it crashes when view controller is just created
        DispatchQueue.main.async {
            UIView.setAnimationsEnabled(false)
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            UIView.setAnimationsEnabled(true)
        }
    }

    @objc private func saveButtonSelected(_ sender: UIBarButtonItem) {
        guard let delegate = delegate else { return }

        switch viewModel.selectedConfigurationType {
        case .custom:
            var canSave: Bool = true

            if viewModel.configurationToEdit.isGasPriceValid {
                cells.gasPrice.textField.status = .none
            } else {
                canSave = false
                cells.gasPrice.textField.status = .error(ConfigureTransactionError.gasPriceTooLow.localizedDescription)
            }

            if viewModel.configurationToEdit.isGasLimitValid {
                cells.gasLimit.textField.status = .none
            } else {
                canSave = false
                cells.gasLimit.textField.status = .error(ConfigureTransactionError.gasLimitTooHigh.localizedDescription)
            }

            if viewModel.configurationToEdit.isTotalFeeValid {
                cells.totalFee.textField.status = .none
            } else {
                canSave = false
                cells.totalFee.textField.status = .error(ConfigureTransactionError.gasFeeTooHigh.localizedDescription)
            }

            if viewModel.configurationToEdit.isNonceValid {
                cells.nonce.textField.status = .none
            } else {
                canSave = false
                cells.nonce.textField.status = .error(ConfigureTransactionError.nonceNotPositiveNumber.localizedDescription)
            }

            if viewModel.gasPriceWarning == nil {
                cells.gasPrice.textField.status = .none
            } else {
                cells.gasPrice.textField.status = .error("")
            }

            guard canSave else {
                tableView.reloadData()
                return
            }

            let configuration = makeConfigureSuitableForSaving(from: viewModel.configurationToEdit.configuration)
            delegate.didSaved(customConfiguration: configuration, in: self)
        case .standard, .slow, .fast, .rapid:
            delegate.didSavedToUseDefaultConfigurationType(viewModel.selectedConfigurationType, in: self)
        }
    }

    private func makeConfigureSuitableForSaving(from configuration: TransactionConfiguration) -> TransactionConfiguration {
        let hasUserAdjustedGasPrice = lastSavedConfiguration.hasUserAdjustedGasPrice || (lastSavedConfiguration.gasPrice != configuration.gasPrice)
        let hasUserAdjustedGasLimit = lastSavedConfiguration.hasUserAdjustedGasLimit || (lastSavedConfiguration.gasLimit != configuration.gasLimit)
        let newConfiguration = TransactionConfiguration(
                gasPrice: configuration.gasPrice,
                gasLimit: configuration.gasLimit,
                data: configuration.data,
                nonce: configuration.nonce,
                hasUserAdjustedGasPrice: hasUserAdjustedGasPrice,
                hasUserAdjustedGasLimit: hasUserAdjustedGasLimit
        )
        lastSavedConfiguration = newConfiguration
        return newConfiguration
    }
}

extension ConfigureTransactionViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfRowsInSections(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.sections[indexPath.section] {
        case .configurationTypes:
            let cell: GasSpeedTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel.gasSpeedViewModel(indexPath: indexPath))

            return cell
        case .gasLimit:
            switch viewModel.gasLimitRows[indexPath.row] {
            case .gasLimit:
                cells.gasLimit.configure(viewModel: viewModel.gasLimitSliderViewModel)
                cells.gasLimit.delegate = self
                cells.gasLimit.textField.inputAccessoryButtonType = .next

                return cells.gasLimit
            case .nonce:
                cells.nonce.configure(viewModel: viewModel.nonceViewModel)
                cells.nonce.textField.delegate = self
                cells.nonce.textField.inputAccessoryButtonType = .next

                return cells.nonce
            case .totalFee:
                cells.totalFee.configure(viewModel: viewModel.totalFeeViewModel)
                cells.totalFee.textField.delegate = self
                cells.totalFee.textField.inputAccessoryButtonType = .next

                return cells.totalFee
            case .transactionData:
                cells.data.configure(viewModel: viewModel.dataViewModel)
                cells.data.textField.delegate = self
                cells.data.textField.inputAccessoryButtonType = .done

                return cells.data
            }
        case .gasPrice:
            cells.gasPrice.configure(viewModel: viewModel.gasPriceSliderViewModel)
            cells.gasPrice.delegate = self
            cells.gasPrice.textField.inputAccessoryButtonType = .next

            return cells.gasPrice
        }
    }
}

extension ConfigureTransactionViewController: SliderTableViewCellDelegate {

    func cell(_ cell: SliderTableViewCell, textDidChange value: Int) {
        if cell == cells.gasLimit {
            viewModel.configurationToEdit.gasLimitRawValue = value
            viewModel.configurationToEdit.updateMaxGasLimitIfNeeded(value)

            cells.gasLimit.configureSliderRange(viewModel: viewModel.gasLimitSliderViewModel)
        } else if cell == cells.gasPrice {
            viewModel.configurationToEdit.updateMaxGasPriceIfNeeded(value)
            viewModel.configurationToEdit.gasPriceRawValue = value

            cells.gasPrice.configureSliderRange(viewModel: viewModel.gasPriceSliderViewModel)
        }

        recalculateTotalFeeForCustomGas()
    }

    func cell(_ cell: SliderTableViewCell, valueDidChange value: Int) {
        if cell == cells.gasLimit {
            viewModel.configurationToEdit.gasLimitRawValue = value
        } else if cell == cells.gasPrice {
            viewModel.configurationToEdit.gasPriceRawValue = value
        }

        recalculateTotalFeeForCustomGas()
    }
}

extension ConfigureTransactionViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.sections[section] {
        case .configurationTypes:
            return nil
        case .gasPrice:
            let view: GasSpeedTableViewHeaderView = tableView.dequeueReusableHeaderFooterView()
            view.configure(viewModel: .init(title: viewModel.gasPriceHeaderTitle))

            return view
        case .gasLimit:
            let view: GasSpeedTableViewHeaderView = tableView.dequeueReusableHeaderFooterView()
            view.configure(viewModel: .init(title: viewModel.gasLimitHeaderTitle))

            return view
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModel.sections[section] {
        case .configurationTypes:
            return 0.01
        case .gasLimit, .gasPrice:
            return GasSpeedTableViewHeaderView.height
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch viewModel.sections[indexPath.section] {
        case .configurationTypes:
            viewModel.selectedConfigurationType = viewModel.configurationTypes[indexPath.row]
        case .gasLimit, .gasPrice:
            break
        }

        tableView.reloadData()
    }
}

extension ConfigureTransactionViewController: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        return true
    }

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: TextField) {
        if textField == cells.gasPrice.textField {
            cells.gasLimit.textField.becomeFirstResponder()
        } else if textField == cells.gasLimit.textField {
            cells.nonce.textField.becomeFirstResponder()
        } else if textField == cells.nonce.textField {
            cells.data.textField.becomeFirstResponder()
        }
    }

    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        let value = (textField.value as NSString).replacingCharacters(in: range, with: string)

        if textField == cells.data.textField {
            viewModel.configurationToEdit.dataRawValue = value
        } else if textField == cells.nonce.textField {
            viewModel.configurationToEdit.nonceRawValue = Int(value)
        }

        return true
    }
}

extension UIBarButtonItem {

    static func saveBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        .init(title: R.string.localizable.save(), style: .plain, target: target, action: selector)
    }

    static func backBarButton(selectionClosure: @escaping () -> Void) -> UIBarButtonItem {
        let barButton = UIBarButtonItem(image: R.image.backWhite(), style: .plain, target: nil, action: nil)
        barButton.selectionClosure = selectionClosure

        return barButton
    }

    private struct AssociatedObject {
        static var key = "action_closure_key"
    }

    var selectionClosure: (() -> Void)? {
        get {
            return objc_getAssociatedObject(self, &AssociatedObject.key) as? () -> Void
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObject.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            target = self
            action = #selector(didTapButton)
        }
    }

    @objc func didTapButton(_ sender: Any) {
        selectionClosure?()
    }
}
