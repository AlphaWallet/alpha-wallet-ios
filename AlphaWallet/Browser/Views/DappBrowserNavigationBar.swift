// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletCore
import AlphaWalletFoundation

protocol DappBrowserNavigationBarDelegate: AnyObject {
    func didTyped(text: String, in navigationBar: DappBrowserNavigationBar)
    func didEnter(text: String, in navigationBar: DappBrowserNavigationBar)
    func didTapChangeServer(in navigationBar: DappBrowserNavigationBar)
    func didTapBack(in navigationBar: DappBrowserNavigationBar)
    func didTapForward(in navigationBar: DappBrowserNavigationBar)
    func didTapMore(sender: UIView, in navigationBar: DappBrowserNavigationBar)
    func didTapClose(in navigationBar: DappBrowserNavigationBar)
    func didTapHome(sender: UIView, in navigationBar: DappBrowserNavigationBar)
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
    private let moreButton: UIButton = {
        let moreButton = UIButton(type: .system)
        moreButton.tintColor = Configuration.Color.Semantic.navigationBarPrimaryFont
        moreButton.adjustsImageWhenHighlighted = true
        moreButton.setImage(R.image.toolbarMenu(), for: .normal)
        moreButton.backgroundColor = Configuration.Color.Semantic.navigationBarBackgroundColor
        return moreButton
    }()

    private let homeButton: UIButton = {
        let homeButton = UIButton(type: .system)
        homeButton.tintColor = Configuration.Color.Semantic.navigationBarPrimaryFont
        homeButton.adjustsImageWhenHighlighted = true
        homeButton.setImage(R.image.iconsSystemHome(), for: .normal)

        return homeButton
    }()

    //Change server button is remove, for now to make browser more generic
    //TODO re-evaluate if we can put it back
    private let changeServerButton = UIButton(type: .system)
    private let cancelEditingButton: UIButton = {
        let cancelEditingButton = UIButton(type: .system)
        cancelEditingButton.setTitleColor(Configuration.Color.Semantic.navigationBarButtonItemTint, for: .normal)
        //compression and hugging priority required to make cancel button appear reliably yet not be too wide
        cancelEditingButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        cancelEditingButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        cancelEditingButton.isHidden = true
        cancelEditingButton.clipsToBounds = true
        cancelEditingButton.backgroundColor = Configuration.Color.Semantic.backgroundClear
        cancelEditingButton.setTitleColor(Configuration.Color.Semantic.defaultForegroundText, for: .highlighted)
        cancelEditingButton.setTitleColor(Configuration.Color.Semantic.defaultForegroundText, for: .normal)

        return cancelEditingButton
    }()
    private let closeButton: UIButton = {
        let closeButton = UIButton(type: .system)
        closeButton.tintColor = Configuration.Color.Semantic.navigationBarPrimaryFont
        closeButton.isHidden = true
        closeButton.setTitle(R.string.localizable.done(), for: .normal)
        closeButton.setTitleColor(Configuration.Color.Semantic.navigationBarButtonItemTint, for: .normal)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        return closeButton
    }()

    private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.autocapitalizationType = .none
        textField.autoresizingMask = .flexibleWidth
        textField.delegate = self
        textField.autocorrectionType = .no
        textField.returnKeyType = .go
        textField.clearButtonMode = .whileEditing
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 40))
        textField.leftViewMode = .always
        textField.placeholder = R.string.localizable.browserUrlTextfieldPlaceholder()
        textField.keyboardType = .webSearch
        textField.borderStyle = .none
        textField.backgroundColor = Configuration.Color.Semantic.textFieldBackground
        textField.layer.borderWidth = DataEntry.Metric.borderThickness
        textField.layer.borderColor = Configuration.Color.Semantic.borderClear.cgColor
        textField.cornerRadius = DataEntry.Metric.cornerRadius

        return textField
    }()

    private let domainNameLabel = UILabel()
    private let backButton: UIButton = {
        let backButton = UIButton(type: .system)
        backButton.tintColor = Configuration.Color.Semantic.navigationBarPrimaryFont
        backButton.adjustsImageWhenHighlighted = true
        backButton.setImage(R.image.toolbarBack(), for: .normal)

        return backButton
    }()
    private let forwardButton: UIButton = {
        let forwardButton = UIButton(type: .system)
        forwardButton.tintColor = Configuration.Color.Semantic.navigationBarPrimaryFont
        forwardButton.adjustsImageWhenHighlighted = true
        forwardButton.setImage(R.image.toolbarForward(), for: .normal)

        return forwardButton
    }()
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
            //FIXME: need to resolve somehow show/hide animation, show is broken when animation view
            UIView.animate(withDuration: 0.3) {
                self.layoutIfNeeded()
                self.stackView.layoutIfNeeded()
            }
        }
    }
    var isBrowserOnly: Bool {
        return state == .browserOnly
    }

    var url: URL? {
        return textField.text.flatMap { URL(string: $0) }
    }

    weak var navigationBarDelegate: DappBrowserNavigationBarDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        domainNameLabel.isHidden = true

        moreButton.addTarget(self, action: #selector(moreAction), for: .touchUpInside)
        homeButton.addTarget(self, action: #selector(homeAction), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
        changeServerButton.addTarget(self, action: #selector(changeServerAction), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(goBackAction), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(goForwardAction), for: .touchUpInside)
        cancelEditingButton.addTarget(self, action: #selector(cancelEditing), for: .touchUpInside)

        let spacer0 = UIView.spacerWidth()
        let spacer1 = UIView.spacerWidth()
        let spacer2 = UIView.spacerWidth()
        let spacer3 = UIView.spacerWidth(10)
        //NOTE: remove spacing between backButton and forwardButton buttons
        let backwardForwardButtonStackView = [backButton, forwardButton].asStackView(axis: .horizontal)

        viewsToShowWhenNotEditing.append(contentsOf: [spacer0, spacer1, backwardForwardButtonStackView, textField, spacer2, homeButton, spacer3, moreButton])
        viewsToShowWhenEditing.append(contentsOf: [textField, cancelEditingButton])
        viewsToShowWhenBrowserOnly.append(contentsOf: [spacer0, backwardForwardButtonStackView, domainNameLabel, spacer1, closeButton, spacer3, moreButton])

        changeServerButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        changeServerButton.setContentHuggingPriority(.required, for: .horizontal)

        stackView.addArrangedSubviews([
            spacer0,
            backwardForwardButtonStackView,
            textField,
            domainNameLabel,
            spacer1,
            closeButton,
            spacer2,
            homeButton,
            spacer3,
            moreButton,
            cancelEditingButton
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.spacing = 4
        addSubview(stackView)

        let leadingAnchorConstraint = stackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 10)
        let trailingAnchorConstraint = stackView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -10)
        //We really want these constraints to be `.required`, but can't because it AutoLayout complains the instance `this` is created, as it probably starts with a frame of zero and can't fulfill the constants
        leadingAnchorConstraint.priority = .required - 1
        trailingAnchorConstraint.priority = .required - 1

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            leadingAnchorConstraint,
            trailingAnchorConstraint,
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            backButton.widthAnchor.constraint(equalToConstant: Layout.width),
            forwardButton.widthAnchor.constraint(equalToConstant: Layout.width),
            moreButton.widthAnchor.constraint(equalToConstant: Layout.moreButtonWidth),
            homeButton.widthAnchor.constraint(equalToConstant: Layout.moreButtonWidth)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(server: RPCServer) {
        let color = Configuration.Color.Semantic.navigationBarButtonItemTint
        backButton.imageView?.tintColor = color
        forwardButton.imageView?.tintColor = color
        changeServerButton.tintColor = color
        moreButton.imageView?.tintColor = color
        homeButton.imageView?.tintColor = color
        domainNameLabel.textColor = color
        domainNameLabel.textAlignment = .center

        changeServerButton.setTitle(server.name, for: .normal)

        cancelEditingButton.setTitle(R.string.localizable.cancel(), for: .normal)
    }

    func setBrowserBar(hidden: Bool) {
        stackView.isHidden = hidden
    }

    @objc private func goBackAction() {
        cancelEditing()
        navigationBarDelegate?.didTapBack(in: self)
    }

    @objc private func goForwardAction() {
        cancelEditing()
        navigationBarDelegate?.didTapForward(in: self)
    }

    @objc private func moreAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapMore(sender: sender, in: self)
    }

    @objc private func homeAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapHome(sender: sender, in: self)
    }

    @objc private func changeServerAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapChangeServer(in: self)
    }

    @objc private func closeAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapClose(in: self)
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
        homeButton.isEnabled = false
        textField.isEnabled = false
        cancelEditingButton.isEnabled = false
        closeButton.isEnabled = false
    }

    func enableButtons() {
        backButton.isEnabled = true
        forwardButton.isEnabled = true
        changeServerButton.isEnabled = true
        moreButton.isEnabled = true
        homeButton.isEnabled = true
        textField.isEnabled = true
        cancelEditingButton.isEnabled = true
        closeButton.isEnabled = true
    }
}

extension DappBrowserNavigationBar: NavigationBarPresentable {
    func willPush() {
        setBrowserBar(hidden: true)
    }

    func willPop() {
        setBrowserBar(hidden: false)
    }

}

extension DappBrowserNavigationBar: UITextFieldDelegate {

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = Configuration.Color.Semantic.borderClear.cgColor
        textField.backgroundColor = Configuration.Color.Semantic.textFieldBackground

        textField.dropShadow(color: .clear, radius: DataEntry.Metric.shadowRadius)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.backgroundColor = Configuration.Color.Semantic.textFieldBackground
        textField.layer.borderColor = Configuration.Color.Semantic.textFieldShadowWhileEditing.cgColor

        textField.dropShadow(color: Configuration.Color.Semantic.textFieldShadowWhileEditing, radius: DataEntry.Metric.shadowRadius)
    }

    private func queue(typedText text: String) {
        navigationBarDelegate?.didTyped(text: text, in: self)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        navigationBarDelegate?.didEnter(text: textField.text ?? "", in: self)
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
