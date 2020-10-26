// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol SeedPhraseBackupIntroductionViewControllerDelegate: class {
    func didTapBackupWallet(inViewController viewController: SeedPhraseBackupIntroductionViewController)
    func didClose(for account: AlphaWallet.Address, inViewController viewController: SeedPhraseBackupIntroductionViewController)
}

class SeedPhraseBackupIntroductionViewController: UIViewController {
    private var viewModel = SeedPhraseBackupIntroductionViewModel()
    private let account: AlphaWallet.Address
    private let roundedBackground = RoundedBackground()
    private let subtitleLabel = UILabel()
    private let imageView = UIImageView()
    private let descriptionLabel1 = UILabel()
    let descriptionLabel2 = UILabel()
    let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))

    private var imageViewDimension: CGFloat {
        if ScreenChecker().isNarrowScreen {
            return 180
        } else {
            return 250
        }
    }

    weak var delegate: SeedPhraseBackupIntroductionViewControllerDelegate?

    init(account: AlphaWallet.Address) {
        self.account = account
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        imageView.contentMode = .scaleAspectFit

        let stackView = [
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 22 : 32),
            subtitleLabel,
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 20 : 24),
            imageView,
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 7 : 17),
            descriptionLabel1,
            UIView.spacer(height: ScreenChecker().isNarrowScreen ? 7 : 17),
            descriptionLabel2
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: imageViewDimension),

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
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
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
    }

    func configure() {
        view.backgroundColor = Colors.appBackground

        subtitleLabel.numberOfLines = 0
        subtitleLabel.attributedText = viewModel.attributedSubtitle

        imageView.image = viewModel.imageViewImage

        descriptionLabel1.numberOfLines = 0
        descriptionLabel1.attributedText = viewModel.attributedDescription

        descriptionLabel2.numberOfLines = 0
        descriptionLabel2.attributedText = viewModel.attributedWarningDescription

        buttonsBar.configure()
        let exportButton = buttonsBar.buttons[0]
        exportButton.setTitle(viewModel.title, for: .normal)
        exportButton.addTarget(self, action: #selector(tappedExportButton), for: .touchUpInside)
    }

    @objc private func tappedExportButton() {
        delegate?.didTapBackupWallet(inViewController: self)
    }
}
