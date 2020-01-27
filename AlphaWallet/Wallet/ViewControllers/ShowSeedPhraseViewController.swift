// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import LocalAuthentication

protocol ShowSeedPhraseViewControllerDelegate: class {
    var contextToShowSeedPhrase: LAContext { get }
    var isInactiveBecauseWeAccessingBiometrics: Bool { get set }

    func didTapTestSeedPhrase(for account: EthereumAccount, inViewController viewController: ShowSeedPhraseViewController)
    func biometricsFailed(for account: EthereumAccount, inViewController viewController: ShowSeedPhraseViewController)
}

//We must be careful to no longer show the seedphrase and remove it from memory when this screen is hidden because another VC is displayed over it or because the device is locked
class ShowSeedPhraseViewController: UIViewController {
    private enum State {
        case notDisplayedSeedPhrase
        case displayingSeedPhrase(words: [String])
        case errorDisplaySeedPhrase(KeystoreError)
        case done
    }

    private var viewModel: ShowSeedPhraseViewModel {
        didSet {
            seedPhraseCollectionView.viewModel = .init(words: viewModel.words, shouldShowSequenceNumber: true)
        }
    }
    private let keystore: Keystore
    private let account: EthereumAccount
    private let roundedBackground = RoundedBackground()
    private let subtitleLabel = UILabel()
    private let errorLabel = UILabel()
    private var state: State = .notDisplayedSeedPhrase {
        didSet {
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
            configure()
        }
    }
    private let seedPhraseCollectionView = SeedPhraseCollectionView()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
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

    init(keystore: Keystore, account: EthereumAccount) {
        self.keystore = keystore
        self.account = account
        self.viewModel = .init(words: [])
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        let stackView = [
            UIView.spacer(height: 30),
            subtitleLabel,
            UIView.spacer(height: 10),
            errorLabel,
            UIView.spacer(height: 50),
            seedPhraseCollectionView,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -7),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            roundedBackground.createConstraintsWithContainer(view: view),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didTakeScreenShot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)

        hidesBottomBarWhenPushed = true
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
        keystore.exportSeedPhraseOfHdWallet(forAccount: account, context: context, reason: .backup) { result in
            switch result {
            case .success(let words): 
                self.state = .displayingSeedPhrase(words: words.split(separator: " ").map { String($0) })
            case .failure(let error):
                self.state = .errorDisplaySeedPhrase(error)
                self.delegate?.biometricsFailed(for: self.account, inViewController: self)
            }
        }
    }

    func configure() {
        view.backgroundColor = Colors.appBackground

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        //Important for smaller screens
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = viewModel.subtitle

        errorLabel.textColor = viewModel.errorColor
        errorLabel.font = viewModel.errorFont
        errorLabel.text = viewModel.errorMessage

        seedPhraseCollectionView.configure()

        buttonsBar.configure()
        let testSeedPhraseButton = buttonsBar.buttons[0]
        testSeedPhraseButton.setTitle(R.string.localizable.walletsShowSeedPhraseTestSeedPhrase(), for: .normal)
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
