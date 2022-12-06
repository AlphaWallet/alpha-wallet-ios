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
        label.backgroundColor = Configuration.Color.Semantic.defaultInverseText
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: Fonts.regular(size: 13.0))
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.text = R.string.localizable.settingsAdvancedExportJSONKeystoreFileLabel()
        label.heightAnchor.constraint(equalToConstant: 22.0).isActive = true

        return label
    }()
    lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = Configuration.Color.Semantic.tableViewAccessoryBackground
        textView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: Fonts.regular(size: 17.0))
        textView.textColor = Configuration.Color.Semantic.defaultHeadlineText
        textView.borderColor = Configuration.Color.Semantic.textViewFailed
        textView.cornerRadius = 5.0
        textView.borderWidth = 1.0
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.spellCheckingType = .no
        textView.autocorrectionType = .no

        return textView
    }()
    private (set) lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configureView() {
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        let edgeInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: edgeInsets, separatorHeight: 1.0)
        footerBar.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

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
}
