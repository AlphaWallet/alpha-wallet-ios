//
//  EditCustomRPCView.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 7/11/21.
//

import UIKit

@objc protocol KeyboardNavigationDelegateProtocol {
    func gotoNextResponder()
    func gotoPrevResponder()
    func addHttpsText()
}

class SaveCustomRpcView: UIView {
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var scrollViewBottomConstraint: NSLayoutConstraint!
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()

    var chainNameTextField: TextField = {
        let textField = defaultTextField(
            .default,
            placeHolder: R.string.localizable.addrpcServerNetworkNameTitle(),
            label: R.string.localizable.addrpcServerNetworkNameTitle())
        return textField
    }()

    var rpcEndPointTextField: TextField = {
        let textField = defaultTextField(
            .URL,
            placeHolder: R.string.localizable.addrpcServerRpcUrlPlaceholder(),
            label: R.string.localizable.addrpcServerRpcUrlTitle())
        return textField
    }()

    var chainIDTextField: TextField = {
        let textField = defaultTextField(
            .decimalPad,
            placeHolder: R.string.localizable.chainID(),
            label: R.string.localizable.chainID())
        return textField
    }()

    var symbolTextField: TextField = {
        let textField = defaultTextField(
            .default,
            placeHolder: R.string.localizable.symbol(),
            label: R.string.localizable.symbol())
        return textField
    }()

    var explorerEndpointTextField: TextField = {
        let textField = defaultTextField(
            .URL,
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addBackgroundGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        roundedBackground.addGestureRecognizer(gestureRecognizer)
    }

    func configureKeyboard(keyboardChecker: KeyboardChecker) {
        keyboardChecker.constraint = scrollViewBottomConstraint
    }

    func addSaveButtonTarget(_ target: Any?, action: Selector) {
        let button = buttonsBar.buttons[0]
        button.removeTarget(target, action: action, for: .touchUpInside)
        button.addTarget(target, action: action, for: .touchUpInside)
    }

    private func configure() {
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        scrollViewBottomConstraint.constant = -UIApplication.shared.bottomSafeAreaHeight

        let stackView = (
            TextField.layoutSubviews(for: chainNameTextField) +
            TextField.layoutSubviews(for: rpcEndPointTextField) +
            TextField.layoutSubviews(for: chainIDTextField) +
            TextField.layoutSubviews(for: symbolTextField) +
            TextField.layoutSubviews(for: explorerEndpointTextField) +
            [
                isTestNetworkView,
                .spacer(height: 40)
            ]
        ).asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: .zero, separatorHeight: 0.0)
        scrollView.addSubview(footerBar)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            scrollViewBottomConstraint,

            footerBar.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            footerBar.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: self))
    }

    func configureView() {
        buttonsBar.configure()
        chainNameTextField.configureOnce()
        rpcEndPointTextField.configureOnce()
        chainIDTextField.configureOnce()
        symbolTextField.configureOnce()
        explorerEndpointTextField.configureOnce()
        buttonsBar.buttons[0].setTitle(R.string.localizable.editCustomRPCSaveButtonTitle(preferredLanguages: nil), for: .normal)
        configureInputAccessoryView()
    }

    func resetAllTextFieldStatus() {
        for field in allTextFields {
            field.status = .none
        }
    }

    func unobscure(textField: TextField) {
        guard textField != allTextFields.first else {
            self.scrollView.setContentOffset(.zero, animated: true)
            return
        }
        let rect = self.scrollView.convert(textField.bounds, from: textField)
        self.scrollView.scrollRectToVisible(rect, animated: true)
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

extension SaveCustomRpcView: KeyboardNavigationDelegateProtocol {
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

fileprivate func defaultTextField(_ type: UIKeyboardType, placeHolder: String, label: String) -> TextField {
    let textField = TextField()
    textField.label.translatesAutoresizingMaskIntoConstraints = false
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.keyboardType = type
    textField.textField.autocorrectionType = .no
    textField.textField.autocapitalizationType = .none
    textField.textField.spellCheckingType = .no
    textField.returnKeyType = .next
    textField.placeholder = placeHolder
    textField.label.text = label
    return textField
}

fileprivate func navToolbar(for delegate: KeyboardNavigationDelegateProtocol) -> UIToolbar {
    let toolbar = UIToolbar(frame: .zero)
    let prev = UIBarButtonItem(title: "<", style: .plain, target: delegate, action: #selector(delegate.gotoPrevResponder))
    let next = UIBarButtonItem(title: ">", style: .plain, target: delegate, action: #selector(delegate.gotoNextResponder))
    let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [prev, next, flexSpace]
    toolbar.sizeToFit()
    return toolbar
}

fileprivate func urlToolbar(for delegate: KeyboardNavigationDelegateProtocol) -> UIToolbar {
    let toolbar = UIToolbar(frame: .zero)
    let prev = UIBarButtonItem(title: "<", style: .plain, target: delegate, action: #selector(delegate.gotoPrevResponder))
    let next = UIBarButtonItem(title: ">", style: .plain, target: delegate, action: #selector(delegate.gotoNextResponder))
    let https = UIBarButtonItem(title: "https://", style: .plain, target: delegate, action: #selector(delegate.addHttpsText))
    let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    toolbar.items = [prev, next, https, flexSpace]
    toolbar.sizeToFit()
    return toolbar
}
