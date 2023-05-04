// Copyright © 2019 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol SeedPhraseBackupIntroductionViewControllerDelegate: AnyObject {
    func didTapBackupWallet(inViewController viewController: SeedPhraseBackupIntroductionViewController)
    func didClose(for account: AlphaWallet.Address, inViewController viewController: SeedPhraseBackupIntroductionViewController)
}

class SeedPhraseBackupIntroductionViewController: UIViewController {
    private var viewModel = SeedPhraseBackupIntroductionViewModel()
    private let account: AlphaWallet.Address
    private let subtitleLabel = UILabel()
    private let imageView = UIImageView()
    // NOTE: internal level, for test cases
    let descriptionLabel1 = UILabel()
    let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))

    private var imageViewDimension: CGFloat {
        return ScreenChecker.size(big: 250, medium: 250, small: 220)
    }

    weak var delegate: SeedPhraseBackupIntroductionViewControllerDelegate?

    init(account: AlphaWallet.Address) {
        self.account = account
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        imageView.contentMode = .scaleAspectFit

        let stackView = [
            UIView.spacer(height: ScreenChecker.size(big: 32, medium: 22, small: 18)),
            subtitleLabel,
            UIView.spacer(height: ScreenChecker.size(big: 24, medium: 20, small: 18)),
            imageView,
            UIView.spacer(height: ScreenChecker.size(big: 17, medium: 15, small: 10)),
            descriptionLabel1,
            ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)
        
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: imageViewDimension),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    func configure() {
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        subtitleLabel.numberOfLines = 0
        subtitleLabel.attributedText = viewModel.attributedSubtitle

        imageView.image = viewModel.imageViewImage

        descriptionLabel1.numberOfLines = 0
        descriptionLabel1.attributedText = viewModel.attributedDescription

        buttonsBar.configure()
        let exportButton = buttonsBar.buttons[0]
        exportButton.setTitle(viewModel.title, for: .normal)
        exportButton.addTarget(self, action: #selector(tappedExportButton), for: .touchUpInside)
    }

    @objc private func tappedExportButton() {
        delegate?.didTapBackupWallet(inViewController: self)
    }
}

extension SeedPhraseBackupIntroductionViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(for: account, inViewController: self)
    }
}
