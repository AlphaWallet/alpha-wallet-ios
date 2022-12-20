// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import LocalAuthentication
import AlphaWalletFoundation
import Combine

protocol VerifySeedPhraseViewControllerDelegate: AnyObject {
    var contextToVerifySeedPhrase: LAContext { get }
    var isInactiveBecauseWeAccessingBiometrics: Bool { get set }

    func didVerifySeedPhraseSuccessfully(for account: AlphaWallet.Address, in viewController: VerifySeedPhraseViewController)
    func biometricsFailed(for account: AlphaWallet.Address, inViewController viewController: VerifySeedPhraseViewController)
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
    private var cancelable = Set<AnyCancellable>()
    private var viewModel: VerifySeedPhraseViewModel
    private let keystore: Keystore
    private let account: AlphaWallet.Address
    private let analytics: AnalyticsLogger
    private let roundedBackground = RoundedBackground()
    private let subtitleLabel = UILabel()
    private let seedPhraseTextView = UITextView()
    private let seedPhraseCollectionView = SeedPhraseCollectionView()
    private let errorLabel = UILabel()
    private let buttonsBar = VerticalButtonsBar(numberOfButtons: 2)
    private var state: State {
        didSet {
            switch state {
            case .editingSeedPhrase(let words):
                seedPhraseCollectionView.viewModel = .init(words: words, isSelectable: true)
                clearError()
            case .seedPhraseMatched(let words):
                seedPhraseCollectionView.viewModel = .init(words: words, isSelectable: true)
                errorLabel.text = viewModel.noErrorText
                errorLabel.textColor = viewModel.noErrorColor
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderNormalColor
                delegate?.didVerifySeedPhraseSuccessfully(for: account, in: self)
            case .seedPhraseNotMatched:
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
                seedPhraseTextView.text = ""
                buttonsBar.hideButtonInStack(button: clearChooseSeedPhraseButton)
                continueButton.isEnabled = false
            case .errorDisplaySeedPhrase(let error):
                seedPhraseCollectionView.viewModel = .init(words: [], isSelectable: true)
                errorLabel.text = error.errorDescription
                errorLabel.textColor = viewModel.errorColor
                seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderErrorColor
            }
        }
    }
    private var notDisplayingSeedPhrase: Bool {
        switch state {
        case .editingSeedPhrase:
            return false
        case .seedPhraseMatched:
            return false
        case .seedPhraseNotMatched:
            return false
        case .keystoreError:
            return false
        case .notDisplayedSeedPhrase:
            return true
        case .errorDisplaySeedPhrase:
            return false
        }

    }
    private var clearChooseSeedPhraseButton: UIButton {
        return buttonsBar.buttons[1]
    }
    private var continueButton: UIButton {
        return buttonsBar.buttons[0]
    }

    weak var delegate: VerifySeedPhraseViewControllerDelegate?

    init(keystore: Keystore, account: AlphaWallet.Address, analytics: AnalyticsLogger) {
        self.keystore = keystore
        self.account = account
        self.analytics = analytics
        self.viewModel = .init()
        self.state = .notDisplayedSeedPhrase
        super.init(nibName: nil, bundle: nil)

        seedPhraseCollectionView.bounces = true
        seedPhraseCollectionView.seedPhraseDelegate = self

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false

        seedPhraseTextView.isEditable = false
        //Disable copying
        seedPhraseTextView.isUserInteractionEnabled = false
        seedPhraseTextView.delegate = self

        let stackView = [
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 20: 30),
            subtitleLabel,
            UIView.spacer(height: 10),
            seedPhraseTextView,
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 0: 7),
            errorLabel,
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 5: 24),
            seedPhraseCollectionView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)
        view.addSubview(roundedBackground)

        buttonsBar.hideButtonInStack(button: clearChooseSeedPhraseButton)
        continueButton.isEnabled = false
        roundedBackground.addSubview(buttonsBar)
        seedPhraseTextView.becomeFirstResponder()

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            seedPhraseTextView.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 100: 140),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20.0),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20.0),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: buttonsBar.topAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 20.0),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor, constant: -20.0),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.bottomAnchor.constraint(equalTo: footerBar.bottomAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).set(priority: .defaultHigh),
            footerBar.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -DataEntry.Metric.safeBottom).set(priority: .required),

            roundedBackground.createConstraintsWithContainer(view: view),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didTakeScreenShot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            return
        }
        removeSeedPhraseFromDisplay()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showSeedPhrases()
    }

    @objc private func appDidBecomeActive() {
        showSeedPhrases()
    }

    @objc private func didTakeScreenShot() {
        displaySuccess(message: R.string.localizable.walletsVerifySeedPhraseDoNotTakeScreenshotDescription())
    }

    private func showSeedPhrases() {
        guard isTopViewController else { return }
        guard notDisplayingSeedPhrase else { return }
        guard let context = delegate?.contextToVerifySeedPhrase else { return }
        keystore.exportSeedPhraseOfHdWallet(forAccount: account, context: context, prompt: KeystoreExportReason.prepareForVerification.description)
            .sink { result in
                switch result {
                case .success(let words):
                    self.state = .editingSeedPhrase(words: words.split(separator: " ").map { String($0) }.shuffled())
                case .failure(let error):
                    self.state = .errorDisplaySeedPhrase(error)
                    self.delegate?.biometricsFailed(for: self.account, inViewController: self)
                }
            }.store(in: &cancelable)
    }

    func configure() {
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        //Important for smaller screens
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = viewModel.title

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

        continueButton.setTitle(R.string.localizable.walletsVerifySeedPhraseTitle(), for: .normal)
        continueButton.addTarget(self, action: #selector(verify), for: .touchUpInside)
    }

    @objc func clearChosenSeedPhrases() {
        seedPhraseTextView.text = ""
        seedPhraseCollectionView.viewModel.clearSelectedWords()
        buttonsBar.hideButtonInStack(button: clearChooseSeedPhraseButton)
        continueButton.isEnabled = false
        state = .editingSeedPhrase(words: state.words)
    }

    @objc func verify() {
        guard let context = delegate?.contextToVerifySeedPhrase else { return }
        keystore.verifySeedPhraseOfHdWallet(seedPhraseTextView.text.lowercased().trimmed, forAccount: account, prompt: R.string.localizable.keystoreAccessKeyHdVerify(), context: context)
            .sink { result in
                switch result {
                case .success(let isMatched):
                    //Safety precaution, we clear the seed phrase. The next screen may be the prompt to elevate security of wallet screen which the user can go back from
                    self.clearChosenSeedPhrases()
                    self.updateStateWithVerificationResult(isMatched)
                case .failure(let error):
                    self.reflectError(error)
                    self.delegate?.biometricsFailed(for: self.account, inViewController: self)
                }
            }.store(in: &cancelable)
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

    func removeSeedPhraseFromDisplay() {
        state = .notDisplayedSeedPhrase
    }

    private func clearError() {
        errorLabel.text = viewModel.noErrorText
        errorLabel.textColor = viewModel.noErrorColor
        seedPhraseTextView.borderColor = viewModel.seedPhraseTextViewBorderNormalColor
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
    func didTap(word: String, atIndex index: Int, inCollectionView collectionView: SeedPhraseCollectionView) {
        if seedPhraseTextView.text.isEmpty {
            seedPhraseTextView.text += word
        } else {
            seedPhraseTextView.text += " \(word)"
        }
        clearError()
        if collectionView.viewModel.isEveryWordSelected {
            buttonsBar.showButtonInStack(button: clearChooseSeedPhraseButton, position: 1)
            continueButton.isEnabled = true
        } else {
            buttonsBar.showButtonInStack(button: clearChooseSeedPhraseButton, position: 1)
            continueButton.isEnabled = false
        }
    }
}
