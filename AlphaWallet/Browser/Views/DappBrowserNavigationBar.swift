// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol DappBrowserNavigationBarDelegate: class {
    func didTyped(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didEnter(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapChangeServer(inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapBack(inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapForward(inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapMore(sender: UIView, inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapClose(inNavigationBar navigationBar: DappBrowserNavigationBar)
}

private enum State {
    case editingURLTextField
    case notEditingURLTextField
    case browserOnly
}

private struct Layout {
    static let textFieldHeight: CGFloat = 40
    static let width: CGFloat = 34
    static let moreButtonWidth: CGFloat = 24
}

final class DappBrowserNavigationBar: UINavigationBar {
    private let stackView = UIStackView()
    private let moreButton = UIButton()
    //Change server button is remove, for now to make browser more generic
    //TODO re-evaluate if we can put it back
    private let changeServerButton = UIButton()
    private let cancelEditingButton = UIButton()
    private let closeButton = UIButton()

    private let textField = UITextField()
    private let domainNameLabel = UILabel()
    private let backButton = UIButton()
    private let forwardButton = UIButton()
    private var viewsToShowWhenNotEditing = [UIView]()
    private var viewsToShowWhenEditing = [UIView]()
    private var viewsToShowWhenBrowserOnly = [UIView]()
    private var state = State.notEditingURLTextField {
        didSet {
            var show: [UIView]
            var hide: [UIView]
            switch state {
            case .editingURLTextField:
                hide = viewsToShowWhenNotEditing + viewsToShowWhenBrowserOnly - viewsToShowWhenEditing
                show = viewsToShowWhenEditing
            case .notEditingURLTextField:
                hide = viewsToShowWhenEditing + viewsToShowWhenBrowserOnly - viewsToShowWhenNotEditing
                show = viewsToShowWhenNotEditing
            case .browserOnly:
                hide = viewsToShowWhenEditing + viewsToShowWhenNotEditing - viewsToShowWhenBrowserOnly
                show = viewsToShowWhenBrowserOnly
            }
            hide.hideAll()
            show.showAll()
            UIView.animate(withDuration: 0.3) {
                self.stackView.layoutIfNeeded()
            }
        }
    }
    var isBrowserOnly: Bool {
        return state == .browserOnly
    }

    var url: URL? {
        guard let url = textField.text else { return nil }
        return URL(string: url)
    }

    weak var navigationBarDelegate: DappBrowserNavigationBarDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        textField.autocapitalizationType = .none
        textField.autoresizingMask = .flexibleWidth
        textField.delegate = self
        textField.autocorrectionType = .no
        textField.returnKeyType = .go
        textField.clearButtonMode = .whileEditing
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 30))
        textField.leftViewMode = .always
        textField.placeholder = R.string.localizable.browserUrlTextfieldPlaceholder()
        textField.keyboardType = .webSearch
        textField.borderStyle = .none
        textField.backgroundColor = .white
        textField.layer.borderWidth = DataEntry.Metric.borderThickness
        textField.backgroundColor = DataEntry.Color.searchTextFieldBackground
        textField.layer.borderColor = UIColor.clear.cgColor
        textField.cornerRadius = DataEntry.Metric.cornerRadius
        
        domainNameLabel.isHidden = true

        moreButton.setImage(R.image.toolbarMenu(), for: .normal)
        moreButton.addTarget(self, action: #selector(moreAction(_:)), for: .touchUpInside)

        closeButton.isHidden = true
        closeButton.setTitle(R.string.localizable.done(), for: .normal)
        closeButton.setTitleColor(Colors.navigationButtonTintColor, for: .normal)
        closeButton.addTarget(self, action: #selector(closeAction(_:)), for: .touchUpInside)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        changeServerButton.addTarget(self, action: #selector(changeServerAction(_:)), for: .touchUpInside)

        backButton.setImage(R.image.toolbarBack(), for: .normal)
        backButton.addTarget(self, action: #selector(goBackAction), for: .touchUpInside)

        forwardButton.setImage(R.image.toolbarForward(), for: .normal)
        forwardButton.addTarget(self, action: #selector(goForwardAction), for: .touchUpInside)

        cancelEditingButton.setTitleColor(Colors.navigationButtonTintColor, for: .normal)
        //compression and hugging priority required to make cancel button appear reliably yet not be too wide
        cancelEditingButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        cancelEditingButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        cancelEditingButton.addTarget(self, action: #selector(cancelEditing), for: .touchUpInside)

        let spacer0 = UIView.spacerWidth()
        let spacer1 = UIView.spacerWidth()
        let spacer2 = UIView.spacerWidth()
        viewsToShowWhenNotEditing.append(contentsOf: [spacer0, spacer1, backButton, forwardButton, textField, spacer2, moreButton])
        viewsToShowWhenEditing.append(contentsOf: [textField, cancelEditingButton])
        viewsToShowWhenBrowserOnly.append(contentsOf: [spacer0, backButton, forwardButton, domainNameLabel, spacer1, closeButton, spacer2, moreButton])

        cancelEditingButton.isHidden = true

        changeServerButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        changeServerButton.setContentHuggingPriority(.required, for: .horizontal)
        stackView.addArrangedSubviews([
            spacer0,
            backButton,
            forwardButton,
            textField,
            domainNameLabel,
            spacer1,
            closeButton,
            spacer2,
            moreButton,
            cancelEditingButton,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.spacing = 4 
        addSubview(stackView)

        let leadingAnchorConstraint = stackView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor, constant: 10)
        let trailingAnchorConstraint = stackView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor, constant: -10)
        //We really want these constraints to be `.required`, but can't because it AutoLayout complains the instance `this` is created, as it probably starts with a frame of zero and can't fulfill the constants
        leadingAnchorConstraint.priority = .required - 1
        trailingAnchorConstraint.priority = .required - 1

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 54),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            leadingAnchorConstraint,
            trailingAnchorConstraint,
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            backButton.widthAnchor.constraint(equalToConstant: Layout.width),
            forwardButton.widthAnchor.constraint(equalToConstant: Layout.width),
            moreButton.widthAnchor.constraint(equalToConstant: Layout.moreButtonWidth),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(server: RPCServer) {
        let color = Colors.navigationButtonTintColor
        backButton.imageView?.tintColor = color
        forwardButton.imageView?.tintColor = color
        changeServerButton.tintColor = color
        moreButton.imageView?.tintColor = color

        domainNameLabel.textColor = color
        domainNameLabel.textAlignment = .center

        changeServerButton.setTitle(server.name, for: .normal)

        cancelEditingButton.setTitle(R.string.localizable.cancel(), for: .normal)
    }

    @objc private func goBackAction() {
        cancelEditing()
        navigationBarDelegate?.didTapBack(inNavigationBar: self)
    }

    @objc private func goForwardAction() {
        cancelEditing()
        navigationBarDelegate?.didTapForward(inNavigationBar: self)
    }

    @objc private func moreAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapMore(sender: sender, inNavigationBar: self)
    }

    @objc private func changeServerAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapChangeServer(inNavigationBar: self)
    }

    @objc private func closeAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapClose(inNavigationBar: self)
    }

    //TODO this might get triggered immediately if we use a physical keyboard. Verify
    @objc func cancelEditing() {
        dismissKeyboard()
        switch state {
        case .editingURLTextField:
            self.state = .notEditingURLTextField
        case .notEditingURLTextField, .browserOnly:
            //We especially don't want to switch (and animate) to .notEditingURLTextField when we are closing .browserOnly mode
            break
        }
    }

    func display(url: URL) {
        textField.text = url.absoluteString
        domainNameLabel.text = URL(string: url.absoluteString)?.host ?? ""
    }

    func display(string: String) {
        textField.text = string
    }

    func clearDisplay() {
        display(string: "")
    }

    private func dismissKeyboard() {
        endEditing(true)
    }

    func makeBrowserOnly() {
        state = .browserOnly
    }

    func disableButtons() {
        backButton.isEnabled = false
        forwardButton.isEnabled = false
        changeServerButton.isEnabled = false
        moreButton.isEnabled = false
        textField.isEnabled = false
        cancelEditingButton.isEnabled = false
        closeButton.isEnabled = false
    }

    func enableButtons() {
        backButton.isEnabled = true
        forwardButton.isEnabled = true
        changeServerButton.isEnabled = true
        moreButton.isEnabled = true
        textField.isEnabled = true
        cancelEditingButton.isEnabled = true
        closeButton.isEnabled = true
    }
}

extension DappBrowserNavigationBar: UITextFieldDelegate {
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.clear.cgColor
        textField.backgroundColor = DataEntry.Color.searchTextFieldBackground
        
        textField.dropShadow(color: .clear, radius: DataEntry.Metric.shadowRadius)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.backgroundColor = DataEntry.Color.textFieldBackgroundWhileEditing
        textField.layer.borderColor = DataEntry.Color.textFieldShadowWhileEditing.cgColor
        
        textField.dropShadow(color: DataEntry.Color.textFieldShadowWhileEditing, radius: DataEntry.Metric.shadowRadius)
    }
    
    private func queue(typedText text: String) {
        navigationBarDelegate?.didTyped(text: text, inNavigationBar: self)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        navigationBarDelegate?.didEnter(text: textField.text ?? "", inNavigationBar: self)
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String
    ) -> Bool {
        if let text = textField.text, let range = Range(range, in: text) {
            queue(typedText: textField.text?.replacingCharacters(in: range, with: string) ?? "")
        } else {
            queue(typedText: "")
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        queue(typedText: "")
        return true
    }

    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        self.state = .editingURLTextField
        return true
    }
}
