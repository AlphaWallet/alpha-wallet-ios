// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import LocalAuthentication
import AlphaWalletFoundation
import Combine

protocol ShowSeedPhraseViewControllerDelegate: AnyObject {
    var contextToShowSeedPhrase: LAContext { get }
    var isInactiveBecauseWeAccessingBiometrics: Bool { get set }

    func didTapTestSeedPhrase(for account: AlphaWallet.Address, inViewController viewController: ShowSeedPhraseViewController)
    func biometricsFailed(for account: AlphaWallet.Address, inViewController viewController: ShowSeedPhraseViewController)
}

//We must be careful to no longer show the seed phrase and remove it from memory when this screen is hidden because another VC is displayed over it or because the device is locked
class ShowSeedPhraseViewController: UIViewController {
    private enum State {
        case notDisplayedSeedPhrase
        case displayingSeedPhrase(words: [String])
        case errorDisplaySeedPhrase(KeystoreError)
        case done
    }
    private var cancelable = Set<AnyCancellable>()

    private var viewModel: ShowSeedPhraseViewModel {
        didSet {
            seedPhraseCollectionView.viewModel = .init(words: viewModel.words, shouldShowSequenceNumber: true)
        }
    }
    private let keystore: Keystore
    private let account: AlphaWallet.Address
    private let subtitleLabel = UILabel()
    private let errorLabel = UILabel()
    private var state: State = .notDisplayedSeedPhrase {
        didSet {
            let prevViewModel = viewModel
            switch state {
            case .notDisplayedSeedPhrase:
                viewModel = .init(words: [])
            case .displayingSeedPhrase(let words):
                viewModel = .init(words: words)
            case .errorDisplaySeedPhrase(let error):
                viewModel = .init(error: error)
            case .done:
                viewModel = .init(words: [])
            }

            viewModel.subtitle = prevViewModel.subtitle
            viewModel.buttonTitle = prevViewModel.buttonTitle

            configure()
        }
    }
    private let seedPhraseCollectionView = SeedPhraseCollectionView()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var notDisplayingSeedPhrase: Bool {
        switch state {
        case .notDisplayedSeedPhrase:
            return true
        case .displayingSeedPhrase:
            return false
        case .errorDisplaySeedPhrase:
            return false
        case .done:
            return false
        }
    }
    private var isDone: Bool {
        switch state {
        case .notDisplayedSeedPhrase:
            return false
        case .displayingSeedPhrase:
            return false
        case .errorDisplaySeedPhrase:
            return false
        case .done:
            return true
        }
    }
    weak var delegate: ShowSeedPhraseViewControllerDelegate?

    init(keystore: Keystore, account: AlphaWallet.Address, viewModel: ShowSeedPhraseViewModel = .init(words: [])) {
        self.keystore = keystore
        self.account = account
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        let stackView = [
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 10 : 30),
            subtitleLabel,
            UIView.spacer(height: 10),
            errorLabel,
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 10 : 50),
            seedPhraseCollectionView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -7),

            footerBar.anchorsConstraint(to: view)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didTakeScreenShot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)

        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
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
        displaySuccess(message: R.string.localizable.walletsShowSeedPhraseDoNotTakeScreenshotDescription())
    }

    private func showSeedPhrases() {
        guard !isDone else { return }
        guard isTopViewController else { return }
        guard notDisplayingSeedPhrase else { return }
        guard let context = delegate?.contextToShowSeedPhrase else { return }
        keystore.exportSeedPhraseOfHdWallet(forAccount: account, context: context, prompt: KeystoreExportReason.backup.description)
            .sink { result in
                switch result {
                case .success(let words):
                    self.state = .displayingSeedPhrase(words: words.split(separator: " ").map { String($0) })
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
        subtitleLabel.text = viewModel.subtitle

        errorLabel.textColor = viewModel.errorColor
        errorLabel.font = viewModel.errorFont
        errorLabel.text = viewModel.errorMessage
        errorLabel.numberOfLines = 0

        seedPhraseCollectionView.configure()

        buttonsBar.configure()
        let testSeedPhraseButton = buttonsBar.buttons[0]
        testSeedPhraseButton.setTitle(viewModel.buttonTitle, for: .normal)
        testSeedPhraseButton.addTarget(self, action: #selector(testSeedPhrase), for: .touchUpInside)
    }

    @objc private func testSeedPhrase() {
        delegate?.didTapTestSeedPhrase(for: account, inViewController: self)
    }

    func removeSeedPhraseFromDisplay() {
        guard !isDone else { return }
        state = .notDisplayedSeedPhrase
    }

    func markDone() {
        state = .done
    }
}

enum KeystoreExportReason: CustomStringConvertible {
    case backup
    case prepareForVerification

    var description: String {
        switch self {
        case .backup:
            return R.string.localizable.keystoreAccessKeyHdBackup()
        case .prepareForVerification:
            return R.string.localizable.keystoreAccessKeyHdPrepareToVerify()
        }
    }
}
