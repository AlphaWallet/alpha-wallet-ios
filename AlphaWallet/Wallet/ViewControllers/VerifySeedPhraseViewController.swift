// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol VerifySeedPhraseViewControllerDelegate: class {
    func didVerifySeedPhraseSuccessfully(for account: EthereumAccount, in viewController: VerifySeedPhraseViewController)
}

class VerifySeedPhraseViewController: UIViewController {
    private enum State {
        case editingSeedPhrase
        case seedPhraseNotMatched
        case seedPhraseMatched
        case keystoreError(KeystoreError)
    }

    private var viewModel: VerifySeedPhraseViewModel
    private let keystore: Keystore
    private let account: EthereumAccount
    private let roundedBackground = RoundedBackground()
    private let seedPhraseTextView = UITextView()
    private let errorLabel = UILabel()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
    private var state: State {
        didSet {
            switch state {
            case .editingSeedPhrase:
                errorLabel.text = ""
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderNormalColor
            case .seedPhraseMatched:
                errorLabel.text = ""
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderNormalColor
                delegate?.didVerifySeedPhraseSuccessfully(for: account, in: self)
            case .seedPhraseNotMatched:
                errorLabel.text = R.string.localizable.walletsVerifySeedPhraseWrong()
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderErrorColor
            case .keystoreError(let error):
                errorLabel.text = error.errorDescription
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderErrorColor
            }
        }
    }

    weak var delegate: VerifySeedPhraseViewControllerDelegate?

    init(keystore: Keystore, account: EthereumAccount) {
        self.keystore = keystore
        self.account = account
        self.viewModel = .init()
        self.state = .editingSeedPhrase
        super.init(nibName: nil, bundle: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        seedPhraseTextView.delegate = self

        let stackView = [
            UIView.spacer(height: 30),
            seedPhraseTextView,
            UIView.spacer(height: 7),
            errorLabel,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        seedPhraseTextView.becomeFirstResponder()

        NSLayoutConstraint.activate([
            seedPhraseTextView.heightAnchor.constraint(equalToConstant: 140),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        view.backgroundColor = Colors.appBackground

        title = viewModel.title

        seedPhraseTextView.keyboardType = .alphabet
        seedPhraseTextView.returnKeyType = .done
        seedPhraseTextView.autocapitalizationType = .none
        seedPhraseTextView.autocorrectionType = .no
        seedPhraseTextView.enablesReturnKeyAutomatically = true
        seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderNormalColor
        seedPhraseTextView.borderWidth = viewModel.seedPhraseTextViewBorderWidth
        seedPhraseTextView.cornerRadius = viewModel.seedPhraseTextViewBorderCornerRadius
        seedPhraseTextView.font = viewModel.seedPhraseTextViewFont
        seedPhraseTextView.contentInset = viewModel.seedPhraseTextViewContentInset

        errorLabel.textColor = viewModel.errorColor
        errorLabel.font = viewModel.errorFont
        errorLabel.numberOfLines = 0

        buttonsBar.configure()
        let continueButton = buttonsBar.buttons[0]
        continueButton.setTitle(R.string.localizable.walletsVerifySeedPhraseTitle(), for: .normal)
        continueButton.addTarget(self, action: #selector(verify), for: .touchUpInside)
    }

    @objc func verify() {
        keystore.verifySeedPhraseOfHdWallet(seedPhraseTextView.text.lowercased().trimmed, forAccount: account) { result in
            switch result {
            case .success(let isMatched):
                self.updateStateWithVerificationResult(isMatched)
            case .failure(let error):
                self.reflectError(error)
            }
        }
    }

    private func updateStateWithVerificationResult(_ isMatched: Bool) {
        if isMatched {
            state = .seedPhraseMatched
        } else {
            state = .seedPhraseNotMatched
        }
    }

    private func reflectError(_ error: KeystoreError) {
        state = .keystoreError(error)
    }
}


extension VerifySeedPhraseViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            verify()
            seedPhraseTextView.resignFirstResponder()
            return false
        } else {
            state = .editingSeedPhrase
            return true
        }
    }
    
}
