// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class PassphraseViewController: UIViewController {

    let passphraseView = PassphraseView(frame: .zero)
    let viewModel = PassphraseViewModel()

    init(words: [String]) {
        super.init(nibName: nil, bundle: nil)

        navigationItem.title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor

        passphraseView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = viewModel.rememberPassphraseText
        label.font = Fonts.semibold(size: 14)

        let copyButton = Button(size: .small, style: .borderless)
        copyButton.setTitle(R.string.localizable.copy(), for: .normal)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.addTarget(self, action: #selector(copyAction), for: .touchUpInside)

        let stackView = [
            .spacer(height: 10),
            passphraseView,
            copyButton,
            label,
        ].asStackView(axis: .vertical, spacing: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])

        passphraseView.words = words
    }

    @objc private func copyAction() {
        let copyValue = passphraseView.words.joined(separator: " ")
        UIPasteboard.general.string = copyValue
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
