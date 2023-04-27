// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol PromptBackupWalletViewDelegate: AnyObject {
    func viewControllerToShowBackupLaterAlert(forView view: PromptBackupWalletView) -> UIViewController?
    func didChooseBackupLater(inView view: PromptBackupWalletView)
    func didChooseBackup(inView view: PromptBackupWalletView)
}

class PromptBackupWalletView: UIView {
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let backupButton = UIButton(type: .system)
    private let remindMeLaterButton = UIButton(type: .system)
    private let viewModel: PromptBackupWalletViewModel

    weak var delegate: PromptBackupWalletViewDelegate?

    init(viewModel: PromptBackupWalletViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        backupButton.addTarget(self, action: #selector(backup), for: .touchUpInside)
        backupButton.setContentHuggingPriority(.required, for: .horizontal)

        remindMeLaterButton.addTarget(self, action: #selector(remindMeLater), for: .touchUpInside)
        remindMeLaterButton.setContentHuggingPriority(.required, for: .horizontal)

        let row0 = [titleLabel, remindMeLaterButton].asStackView(axis: .horizontal)
        let stackView = [
            row0,
            UIView.spacer(height: 10),
            descriptionLabel,
            UIView.spacer(height: 10),
            backupButton,
        ].asStackView(axis: .vertical, alignment: .leading)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            row0.widthAnchor.constraint(equalTo: stackView.widthAnchor),

            descriptionLabel.widthAnchor.constraint(equalTo: backupButton.widthAnchor, constant: 30),

            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = viewModel.backgroundColor
        cornerRadius = viewModel.cornerRadius

        titleLabel.font = viewModel.titleFont
        titleLabel.textColor = viewModel.titleColor
        titleLabel.text = viewModel.title
        //For small screens
        titleLabel.adjustsFontSizeToFitWidth = true

        remindMeLaterButton.setImage(viewModel.moreButtonImage, for: .normal)
        remindMeLaterButton.tintColor = viewModel.moreButtonColor

        descriptionLabel.font = viewModel.descriptionFont
        descriptionLabel.textColor = viewModel.descriptionColor
        descriptionLabel.text = viewModel.description
        descriptionLabel.numberOfLines = 0

        backupButton.tintColor = viewModel.backupButtonTitleColor
        backupButton.titleLabel?.font = viewModel.backupButtonTitleFont
        backupButton.setBackgroundColor(viewModel.backupButtonBackgroundColor, forState: .normal)
        backupButton.setTitleColor(viewModel.backupButtonTitleColor, for: .normal)
        backupButton.setTitle(viewModel.backupButtonTitle, for: .normal)
        backupButton.setImage(viewModel.backupButtonImage, for: .normal)
        backupButton.contentEdgeInsets = viewModel.backupButtonContentEdgeInsets
        swapButtonTextAndImage(backupButton)
    }

    @objc private func backup() {
        delegate?.didChooseBackup(inView: self)
    }

    @objc private func remindMeLater() {
        guard let presenter = delegate?.viewControllerToShowBackupLaterAlert(forView: self) else { return }
        Task { @MainActor in
            guard case .success = await presenter.confirm(message: R.string.localizable.backupPromptBackupRemindLater()) else { return }
            self.delegate?.didChooseBackupLater(inView: self)
        }
    }

    private func swapButtonTextAndImage(_ button: UIButton) {
        button.titleLabel?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        button.imageView?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        button.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
    }
}
