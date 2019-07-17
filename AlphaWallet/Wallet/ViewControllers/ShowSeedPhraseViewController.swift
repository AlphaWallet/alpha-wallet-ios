// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol ShowSeedPhraseViewControllerDelegate: class {
    func didTapTestSeedPhrase(for account: EthereumAccount, inViewController viewController: ShowSeedPhraseViewController)
    func didClose(for account: EthereumAccount, inViewController viewController: ShowSeedPhraseViewController)
}

//We must be careful to no longer show the seedphrase and remove it from memory when this screen is hidden because another VC is displayed over it or because the device is locked
class ShowSeedPhraseViewController: UIViewController {
    private enum State {
        case notDisplayedSeedPhrase
        case displayingSeedPhrase(words: [String])
        case errorDisplaySeedPhrase(KeystoreError)
    }

    private var viewModel: ShowSeedPhraseViewModel
    private let keystore: Keystore
    private let account: EthereumAccount
    private let roundedBackground = RoundedBackground()
    private let subtitleLabel = UILabel()
    private let descriptionLabel = UILabel()
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
            }
            configure()
        }
    }
    private let seedPhraseCollectionView = { () -> UICollectionView in
        let layout = CollectionViewLeftAlignedFlowLayout()
        layout.sectionInset = .init(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumInteritemSpacing = 7
        layout.minimumLineSpacing = 7
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)

    weak var delegate: ShowSeedPhraseViewControllerDelegate?

    init(keystore: Keystore, account: EthereumAccount) {
        self.keystore = keystore
        self.account = account
        self.viewModel = .init(words: [])
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true
        showSeedPhrases()

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        seedPhraseCollectionView.register(SeedPhraseCell.self, forCellWithReuseIdentifier: SeedPhraseCell.identifier)
        seedPhraseCollectionView.dataSource = self

        let stackView = [
            UIView.spacer(height: 30),
            subtitleLabel,
            descriptionLabel,
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
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

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

        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            delegate?.didClose(for: account, inViewController: self)
            return
        }
        removeSeedPhraseFromDisplay()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showSeedPhrases()
    }

    @objc private func appWillResignsActive() {
        removeSeedPhraseFromDisplay()
    }

    @objc private func appDidBecomeActive() {
        showSeedPhrases()
    }

    private func showSeedPhrases() {
        keystore.exportSeedPhraseHdWallet(forAccount: account) { result in
            switch result {
            case .success(let words):
                self.state = .displayingSeedPhrase(words: words.split(separator: " ").map { String($0) })
            case .failure(let error):
                self.state = .errorDisplaySeedPhrase(error)
            }
        }
    }

    func configure() {
        view.backgroundColor = Colors.appBackground

        title = viewModel.title

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        //Important for smaller screens
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = viewModel.subtitle

        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = viewModel.descriptionColor
        descriptionLabel.font = viewModel.descriptionFont
        descriptionLabel.numberOfLines = 0
        descriptionLabel.text = viewModel.description

        errorLabel.textColor = viewModel.errorColor
        errorLabel.font = viewModel.errorFont
        errorLabel.text = viewModel.errorMessage

        seedPhraseCollectionView.backgroundColor = viewModel.backgroundColor
        seedPhraseCollectionView.reloadData()

        buttonsBar.configure()
        let testSeedPhraseButton = buttonsBar.buttons[0]
        testSeedPhraseButton.setTitle(R.string.localizable.walletsShowSeedPhraseTestSeedPhrase(), for: .normal)
        testSeedPhraseButton.addTarget(self, action: #selector(testSeedPhrase), for: .touchUpInside)
    }

    @objc private func testSeedPhrase() {
        delegate?.didTapTestSeedPhrase(for: account, inViewController: self)
    }

    private func removeSeedPhraseFromDisplay() {
        state = .notDisplayedSeedPhrase
    }
}

extension ShowSeedPhraseViewController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.seedPhraseWordCount
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SeedPhraseCell.identifier, for: indexPath) as! SeedPhraseCell
        let word = viewModel.seedPhraseWord(atIndex: indexPath.item)
        cell.configure(viewModel: .init(word: word))
        return cell
    }
}
