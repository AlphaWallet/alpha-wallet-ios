//
//  ExportJsonKeystoreFileView.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 1/12/21.
//

import UIKit

class ExportJsonKeystoreFileView: UIView {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.backgroundColor = R.color.white()!
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: Fonts.regular(size: 13.0))
        label.textColor = R.color.dove()!
        label.text = R.string.localizable.settingsAdvancedExportJSONKeystoreFileLabel()
        label.heightAnchor.constraint(equalToConstant: 22.0).isActive = true
        return label
    }()
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = R.color.alabaster()!
        textView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: Fonts.regular(size: 17.0))
        textView.textColor = R.color.mine()!
        textView.borderColor = R.color.silver()
        textView.cornerRadius = 5.0
        textView.borderWidth = 1.0
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.spellCheckingType = .no
        textView.autocorrectionType = .no
        return textView
    }()
    private lazy var buttonsBar = ButtonsBar(configuration: .green(buttons: 1))

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        disableButton()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func addPasswordButtonTarget(_ target: Any?, action: Selector) {
        let button = buttonsBar.buttons[0]
        button.removeTarget(target, action: action, for: .touchUpInside)
        button.addTarget(target, action: action, for: .touchUpInside)
    }

    func set(content: String) {
        textView.text = content
    }

    func setButton(title: String) {
        buttonsBar.buttons[0].setTitle(title, for: .normal)
    }

    func disableButton() {
        buttonsBar.buttons[0].isEnabled = false
    }

    func enableButton() {
        buttonsBar.buttons[0].isEnabled = true
    }

    private func configureView() {
        backgroundColor = R.color.white()!
        let footerBar = configureButtonsBar()
        footerBar.backgroundColor = R.color.white()
        addSubview(label)
        addSubview(textView)
        addSubview(footerBar)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 34.0),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16.0),
            label.bottomAnchor.constraint(equalTo: textView.topAnchor, constant: -4.0),

            textView.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            textView.bottomAnchor.constraint(lessThanOrEqualTo: footerBar.topAnchor, constant: -8.0),

            footerBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }

    private func configureButtonsBar() -> ButtonsBarBackgroundView {
        buttonsBar.configure()
        let edgeInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: edgeInsets, separatorHeight: 1.0)
        return footerBar
    }
}
