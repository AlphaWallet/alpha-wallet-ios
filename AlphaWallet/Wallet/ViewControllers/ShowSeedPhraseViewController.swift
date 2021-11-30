// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import LocalAuthentication

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

    private var viewModel: ShowSeedPhraseViewModel {
        didSet {
            seedPhraseCollectionView.viewModel = .init(words: viewModel.words, shouldShowSequenceNumber: true)
        }
    }
    private let keystore: Keystore
    private let account: AlphaWallet.Address
    private let roundedBackground = RoundedBackground()
    private let subtitleLabel = UILabel()
    private var viewWhiteCenter: UIView = {
       let view = UIView()
        view.backgroundColor = Colors.appWhite
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = 5
        return view
    }()
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
    
    private let seedPhraseCollectionView: SeedPhraseCollectionView = {
        let collectionView = SeedPhraseCollectionView()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
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
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.backgroundColor = Colors.appBackground
        view.addSubview(roundedBackground)
       
        view.backgroundColor = Colors.appBackground
        viewWhiteCenter.addSubview(seedPhraseCollectionView)
        let stackView = [
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 10 : 30),
            subtitleLabel
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)
        roundedBackground.addSubview(viewWhiteCenter)
        roundedBackground.addSubview(errorLabel)
        
        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            viewWhiteCenter.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            viewWhiteCenter.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            viewWhiteCenter.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            errorLabel.topAnchor.constraint(equalTo: viewWhiteCenter.bottomAnchor, constant: 10),
            
            seedPhraseCollectionView.leadingAnchor.constraint(equalTo: viewWhiteCenter.leadingAnchor, constant: 16),
            seedPhraseCollectionView.trailingAnchor.constraint(equalTo: viewWhiteCenter.trailingAnchor, constant: -16),
            seedPhraseCollectionView.topAnchor.constraint(equalTo: viewWhiteCenter.topAnchor, constant: 16),
            seedPhraseCollectionView.bottomAnchor.constraint(equalTo: viewWhiteCenter.bottomAnchor, constant: -16),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
            
            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            seedPhraseCollectionView.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 135 : 125),

            roundedBackground.createConstraintsWithContainer(view: view),
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
