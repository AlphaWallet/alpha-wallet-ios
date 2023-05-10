//
//  EditCustomRPCView.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import UIKit

@objc protocol KeyboardNavigationDelegate {
    func gotoNextResponder()
    func gotoPrevResponder()
    func addHttpsText()
}

class SaveCustomRpcManualEntryView: UIView {

    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var scrollViewBottomConstraint: NSLayoutConstraint!
    private let scrollView = ScrollableStackView()

    var chainNameTextField: TextField = {
        let textField = TextField.buildTextField(
            keyboardType: .default,
            placeHolder: R.string.localizable.addrpcServerNetworkNameTitle(),
            label: R.string.localizable.addrpcServerNetworkNameTitle())
        return textField
    }()

    var rpcEndPointTextField: TextField = {
        let textField = TextField.buildTextField(
            keyboardType: .URL,
            placeHolder: R.string.localizable.addrpcServerRpcUrlPlaceholder(),
            label: R.string.localizable.addrpcServerRpcUrlTitle())
        return textField
    }()

    var chainIDTextField: TextField = {
        let textField = TextField.buildTextField(
            keyboardType: .numberPad,
            placeHolder: R.string.localizable.chainID(),
            label: R.string.localizable.chainID())
        return textField
    }()

    var symbolTextField: TextField = {
        let textField = TextField.buildTextField(
            keyboardType: .default,
            placeHolder: R.string.localizable.symbol(),
            label: R.string.localizable.symbol())
        return textField
    }()

    var explorerEndpointTextField: TextField = {
        let textField = TextField.buildTextField(
            keyboardType: .URL,
            placeHolder: R.string.localizable.addrpcServerBlockExplorerUrlPlaceholder(),
            label: R.string.localizable.addrpcServerBlockExplorerUrlTitle())
        textField.returnKeyType = .done
        return textField
    }()

    var allTextFields: [TextField] {
        return [chainNameTextField, rpcEndPointTextField, chainIDTextField, symbolTextField, explorerEndpointTextField]
    }

    var isTestNetworkView: SwitchView = {
        let view = SwitchView()

        return view
    }()

    init(frame: CGRect, isEmbedded: Bool) {
        super.init(frame: frame)
        configure(isEmbedded: isEmbedded)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addBackgroundGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        addGestureRecognizer(gestureRecognizer)
    }

    func addSaveButtonTarget(_ target: Any?, action: Selector) {
        let button = buttonsBar.buttons[0]
        button.removeTarget(target, action: action, for: .touchUpInside)
        button.addTarget(target, action: action, for: .touchUpInside)
    }

    private func configure(isEmbedded: Bool) {
        translatesAutoresizingMaskIntoConstraints = !isEmbedded
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        scrollView.stackView.addArrangedSubviews([
            chainNameTextField.defaultLayout(),
            rpcEndPointTextField.defaultLayout(),
            chainIDTextField.defaultLayout(),
            symbolTextField.defaultLayout(),
            explorerEndpointTextField.defaultLayout(),
            isTestNetworkView,
            .spacer(height: 40)
        ])
        addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0.0)
        addSubview(footerBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            footerBar.anchorsConstraint(to: self)
        ])
    }

    func configureView() {
        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(R.string.localizable.editCustomRPCSaveButtonTitle(preferredLanguages: nil), for: .normal)
        configureInputAccessoryView()
    }

    func resetAllTextFieldStatus() {
        for field in allTextFields {
            field.status = .none
        }
    }

    private func configureInputAccessoryView() {
        let navToolbar = navToolbar(for: self)
        let urlToolbar = urlToolbar(for: self)
        chainNameTextField.textField.inputAccessoryView = navToolbar
        rpcEndPointTextField.textField.inputAccessoryView = urlToolbar
        chainIDTextField.textField.inputAccessoryView = navToolbar
        symbolTextField.textField.inputAccessoryView = navToolbar
        explorerEndpointTextField.textField.inputAccessoryView = urlToolbar
    }

    private func prevTextField() -> TextField? {
        guard let index = allTextFields.firstIndex(where: { $0.textField.isFirstResponder
        }) else { return nil }
        let prevIndex = (index - 1) < 0 ? allTextFields.count - 1 : index - 1
        return allTextFields[prevIndex]
    }

    private func nextTextField() -> TextField? {
        guard let index = allTextFields.firstIndex(where: { $0.textField.isFirstResponder
        }) else { return nil }
        let nextIndex = (index + 1) % allTextFields.count
        return allTextFields[nextIndex]
    }

    private func currentTextField() -> TextField? {
        return allTextFields.first { $0.textField.isFirstResponder }
    }

}

extension SaveCustomRpcManualEntryView: KeyboardNavigationDelegate {

    func gotoNextResponder() {
        nextTextField()?.becomeFirstResponder()
    }

    func gotoPrevResponder() {
        prevTextField()?.becomeFirstResponder()
    }

    func addHttpsText() {
        guard let currentTextField = currentTextField(), let inputString = currentTextField.textField.text, !inputString.lowercased().starts(with: "https://") else { return }
        currentTextField.textField.text = "https://" + inputString
    }

}

fileprivate func navToolbar(for delegate: KeyboardNavigationDelegate) -> UIToolbar {
    let toolbar = UIToolbar(frame: .zero)
    let prev = UIBarButtonItem(title: "<", style: .plain, target: delegate, action: #selector(delegate.gotoPrevResponder))
    let next = UIBarButtonItem(title: ">", style: .plain, target: delegate, action: #selector(delegate.gotoNextResponder))
    let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [prev, next, flexSpace]
    toolbar.sizeToFit()
    return toolbar
}

fileprivate func urlToolbar(for delegate: KeyboardNavigationDelegate) -> UIToolbar {
    let toolbar = UIToolbar(frame: .zero)
    let prev = UIBarButtonItem(title: "<", style: .plain, target: delegate, action: #selector(delegate.gotoPrevResponder))
    let next = UIBarButtonItem(title: ">", style: .plain, target: delegate, action: #selector(delegate.gotoNextResponder))
    let https = UIBarButtonItem(title: "https://", style: .plain, target: delegate, action: #selector(delegate.addHttpsText))
    let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [prev, next, https, flexSpace]
    toolbar.sizeToFit()
    return toolbar
}
