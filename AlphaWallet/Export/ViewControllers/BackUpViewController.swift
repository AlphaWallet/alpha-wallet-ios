// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

protocol BackupViewControllerDelegate: class {
    func didPressBackup(account: Account, in viewController: BackupViewController)
}

class BackupViewController: UIViewController {

    let account: Account
    weak var delegate: BackupViewControllerDelegate?
    let viewModel = BackupViewModel()

    init(account: Account) {
        self.account = account

        super.init(nibName: nil, bundle: nil)

        let warningImageView = UIImageView()
        warningImageView.translatesAutoresizingMaskIntoConstraints = false
        warningImageView.image = R.image.backup_warning()

        let noBackupLabel = UILabel()
        noBackupLabel.translatesAutoresizingMaskIntoConstraints = false
        noBackupLabel.text = viewModel.headlineText
        noBackupLabel.font = Fonts.semibold(size: 24)
        noBackupLabel.adjustsFontSizeToFitWidth = true
        noBackupLabel.textColor = Colors.lightBlack

        let controlMoneyLabel = UILabel()
        controlMoneyLabel.translatesAutoresizingMaskIntoConstraints = false
        controlMoneyLabel.text = R.string.localizable.exportControlYourMoneyLabelTitle()
        controlMoneyLabel.numberOfLines = 0
        controlMoneyLabel.textAlignment = .center
        controlMoneyLabel.textColor = Colors.darkGray

        let neverStoredLabel = UILabel()
        neverStoredLabel.translatesAutoresizingMaskIntoConstraints = false
        neverStoredLabel.text = R.string.localizable.exportNeverStoredLabelTitle()
        neverStoredLabel.numberOfLines = 0
        neverStoredLabel.textAlignment = .center
        neverStoredLabel.textColor = Colors.darkGray

        let backupButton = Button(size: .large, style: .solid)
        backupButton.translatesAutoresizingMaskIntoConstraints = false
        backupButton.setTitle(R.string.localizable.exportBackupButtonTitle(), for: .normal)
        backupButton.addTarget(self, action: #selector(backup), for: .touchUpInside)

        let stackView = [
            warningImageView,
            .spacer(),
            noBackupLabel,
            .spacer(height: 15),
            controlMoneyLabel,
            neverStoredLabel,
            .spacer(height: 15),
            backupButton,
        ].asStackView(axis: .vertical, spacing: 20, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.backgroundColor = .white
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(greaterThanOrEqualTo: view.layoutGuide.topAnchor, constant: StyleLayout.sideMargin),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.layoutGuide.leadingAnchor, constant: StyleLayout.sideMargin),
            stackView.trailingAnchor.constraint(equalTo: view.layoutGuide.trailingAnchor, constant: -StyleLayout.sideMargin),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.layoutGuide.bottomAnchor, constant: -StyleLayout.sideMargin),

            backupButton.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            backupButton.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
        ])
    }

    @objc func backup() {
        delegate?.didPressBackup(account: account, in: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
