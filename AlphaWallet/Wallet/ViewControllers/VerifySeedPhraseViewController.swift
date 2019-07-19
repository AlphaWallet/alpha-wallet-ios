// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol VerifySeedPhraseViewControllerDelegate: class {
    func didVerifySeedPhraseSuccessfully(for account: EthereumAccount, in viewController: VerifySeedPhraseViewController)
}

class VerifySeedPhraseViewController: UIViewController {
    private enum State {
        case editingSeedPhrase(words: [String])
        case seedPhraseNotMatched(words: [String])
        case seedPhraseMatched(words: [String])
        case keystoreError(KeystoreError)
        case notDisplayedSeedPhrase
        case errorDisplaySeedPhrase(KeystoreError)

        var words: [String] {
            switch self {
            case .editingSeedPhrase(let words), .seedPhraseMatched(let words), .seedPhraseNotMatched(let words):
                return words
            case .keystoreError, .notDisplayedSeedPhrase, .errorDisplaySeedPhrase:
                return .init()
            }
        }
    }

    private var viewModel: VerifySeedPhraseViewModel
    private let keystore: Keystore
    private let account: EthereumAccount
    private let roundedBackground = RoundedBackground()
    private let seedPhraseTextView = UITextView()
    private let seedPhraseCollectionView = SeedPhraseCollectionView()
    private let errorLabel = UILabel()
    private let clearChooseSeedPhraseButton = UIButton(type: .system)
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
    private var state: State {
        didSet {
            switch state {
            case .editingSeedPhrase(let words):
                seedPhraseCollectionView.viewModel = .init(words: words, isSelectable: true)
                errorLabel.text = viewModel.noErrorText
                errorLabel.textColor = viewModel.noErrorColor
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderNormalColor
            case .seedPhraseMatched(let words):
                seedPhraseCollectionView.viewModel = .init(words: words, isSelectable: true)
                errorLabel.text = viewModel.noErrorText
                errorLabel.textColor = viewModel.noErrorColor
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderNormalColor
                delegate?.didVerifySeedPhraseSuccessfully(for: account, in: self)
            case .seedPhraseNotMatched(let words):
                seedPhraseCollectionView.viewModel = .init(words: words, isSelectable: true)
                errorLabel.text = R.string.localizable.walletsVerifySeedPhraseWrong()
                errorLabel.textColor = viewModel.errorColor
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderErrorColor
            case .keystoreError(let error):
                seedPhraseCollectionView.viewModel = .init(words: [], isSelectable: true)
                errorLabel.text = error.errorDescription
                errorLabel.textColor = viewModel.errorColor
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderErrorColor
            case .notDisplayedSeedPhrase:
                seedPhraseCollectionView.viewModel = .init(words: [], isSelectable: true)
            case .errorDisplaySeedPhrase(let error):
                seedPhraseCollectionView.viewModel = .init(words: [], isSelectable: true)
                errorLabel.text = error.errorDescription
                errorLabel.textColor = viewModel.errorColor
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderErrorColor
            }
        }
    }

    weak var delegate: VerifySeedPhraseViewControllerDelegate?

    init(keystore: Keystore, account: EthereumAccount) {
        self.keystore = keystore
        self.account = account
        self.viewModel = .init()
        self.state = .notDisplayedSeedPhrase
        super.init(nibName: nil, bundle: nil)

        seedPhraseCollectionView.seedPhraseDelegate = self
        showSeedPhrases()

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        seedPhraseTextView.isEditable = false
        seedPhraseTextView.delegate = self

        let stackView = [
            UIView.spacer(height: 30),
            seedPhraseTextView,
            UIView.spacer(height: 7),
            errorLabel,
            UIView.spacer(height: 30),
            seedPhraseCollectionView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        clearChooseSeedPhraseButton.isHidden = true
        clearChooseSeedPhraseButton.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(clearChooseSeedPhraseButton)

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
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            clearChooseSeedPhraseButton.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 10),
            clearChooseSeedPhraseButton.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor, constant: -10),
            clearChooseSeedPhraseButton.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -20),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignsActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            return
        }
        removeSeedPhraseFromDisplay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showSeedPhrases()
    }
    
    @objc private func appDidBecomeActive() {
        showSeedPhrases()
    }

    @objc private func appWillResignsActive() {
        removeSeedPhraseFromDisplay()
    }

    private func showSeedPhrases() {
        keystore.exportSeedPhraseHdWallet(forAccount: account) { result in
            switch result {
            case .success(let words):
                self.state = .editingSeedPhrase(words: words.split(separator: " ").map { String($0) }.shuffled())
            case .failure(let error):
                self.state = .errorDisplaySeedPhrase(error)
            }
        }
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

        errorLabel.textColor = viewModel.noErrorColor
        errorLabel.text = viewModel.noErrorText
        errorLabel.font = viewModel.errorFont
        errorLabel.numberOfLines = 0

        seedPhraseCollectionView.configure()

        clearChooseSeedPhraseButton.addTarget(self, action: #selector(clearChosenSeedPhrases), for: .touchUpInside)
        clearChooseSeedPhraseButton.setTitle(R.string.localizable.clearButtonTitle(), for: .normal)
        clearChooseSeedPhraseButton.titleLabel?.font = viewModel.importKeystoreJsonButtonFont
        clearChooseSeedPhraseButton.titleLabel?.adjustsFontSizeToFitWidth = true

        buttonsBar.configure()
        let continueButton = buttonsBar.buttons[0]
        continueButton.setTitle(R.string.localizable.walletsVerifySeedPhraseTitle(), for: .normal)
        continueButton.addTarget(self, action: #selector(verify), for: .touchUpInside)
    }

    @objc func clearChosenSeedPhrases() {
        seedPhraseTextView.text = ""
        seedPhraseCollectionView.viewModel.clearSelectedWords()
        clearChooseSeedPhraseButton.isHidden = true
        state = .editingSeedPhrase(words: state.words)
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
            state = .seedPhraseMatched(words: state.words)
        } else {
            state = .seedPhraseNotMatched(words: state.words)
        }
    }

    private func reflectError(_ error: KeystoreError) {
        state = .keystoreError(error)
    }

    private func removeSeedPhraseFromDisplay() {
        state = .notDisplayedSeedPhrase
    }
}


extension VerifySeedPhraseViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            verify()
            seedPhraseTextView.resignFirstResponder()
            return false
        } else {
            state = .editingSeedPhrase(words: state.words)
            return true
        }
    }
    
}

extension VerifySeedPhraseViewController: SeedPhraseCollectionViewDelegate {
    func didTap(word: String, atIndex index: Int, inCollectionView: SeedPhraseCollectionView) {
        if seedPhraseTextView.text.isEmpty {
            seedPhraseTextView.text += word
        } else {
            seedPhraseTextView.text += " \(word)"
        }
        clearChooseSeedPhraseButton.isHidden = false
    }
}
