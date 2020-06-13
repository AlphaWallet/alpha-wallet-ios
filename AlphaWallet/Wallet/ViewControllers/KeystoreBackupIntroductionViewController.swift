// Copyright © 2019 Stormbird PTE. LTD.

import UIKit

protocol KeystoreBackupIntroductionViewControllerDelegate: class {
    func didTapExport(inViewController viewController: KeystoreBackupIntroductionViewController)
}

class KeystoreBackupIntroductionViewController: UIViewController {
    private var viewModel = KeystoreBackupIntroductionViewModel()
    private let roundedBackground = RoundedBackground()
    private let subtitleLabel = UILabel()
    private let imageView = UIImageView()
    private let descriptionLabel = UILabel()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))

    private var imageViewDimension: CGFloat {
        if ScreenChecker().isNarrowScreen {
            return 180
        } else {
            return 250
        }
    }

    weak var delegate: KeystoreBackupIntroductionViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        imageView.contentMode = .scaleAspectFit

        let stackView = [
            UIView.spacer(height: 30),
            subtitleLabel,
            UIView.spacer(height: 40),
            imageView,
            UIView.spacer(height: 40),
            descriptionLabel,
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

        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = viewModel.subtitleColor
        subtitleLabel.font = viewModel.subtitleFont
        subtitleLabel.text = viewModel.subtitle

        imageView.image = viewModel.imageViewImage

        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = viewModel.descriptionColor
        descriptionLabel.font = viewModel.descriptionFont
        descriptionLabel.numberOfLines = 0
        descriptionLabel.text = viewModel.description

        buttonsBar.configure()
        let exportButton = buttonsBar.buttons[0]
        exportButton.setTitle(viewModel.title, for: .normal)
        exportButton.addTarget(self, action: #selector(tappedExportButton), for: .touchUpInside)
    }

    @objc private func tappedExportButton() {
        delegate?.didTapExport(inViewController: self)
    }
}
