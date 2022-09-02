//
//  SelectCurrencyButton.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.05.2020.
//

import UIKit
import AlphaWalletFoundation

class SelectCurrencyButton: UIControl {

    private let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.font = DataEntry.Font.amountTextField

        return label
    }()

    private let expandImageView: UIImageView = {
        let imageView = UIImageView(image: R.image.expandMore())
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    private let currencyIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        return imageView
    }()

    private (set) var actionButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    var expandIconHidden: Bool = false {
        didSet {
            expandImageView.isHidden = expandIconHidden
            actionButton.isUserInteractionEnabled = !expandIconHidden
        }
    }

    var text: String {
        get { return textLabel.text ?? "" }
        set { textLabel.text = newValue }
    }

    var tokenIcon: Subscribable<TokenImage>? {
        get { currencyIconImageView.subscribable }
        set { currencyIconImageView.subscribable = newValue }
    }

    var hasToken: Bool = true {
        didSet {
            whenHasNoTokenView.isHidden = hasToken
            whenHasTokenView.isHidden = !whenHasNoTokenView.isHidden
        }
    }

    private lazy var whenHasTokenView: UIView =  {
        let stackView = [currencyIconImageView, .spacerWidth(7), textLabel, .spacerWidth(10), expandImageView].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var whenHasNoTokenView: UIView =  {
        let view = HasNoTokenView()
        return view
    }()

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        addSubview(whenHasTokenView)
        addSubview(whenHasNoTokenView)
        addSubview(actionButton)

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        hasToken = true

        NSLayoutConstraint.activate([
            whenHasTokenView.anchorsConstraint(to: self),
            whenHasNoTokenView.anchorsConstraint(to: self),
            actionButton.anchorsConstraint(to: self),
            
            currencyIconImageView.widthAnchor.constraint(equalToConstant: 40),
            currencyIconImageView.heightAnchor.constraint(equalToConstant: 40)
        ] + expandImageView.sized(.init(width: 24, height: 24)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        return nil
    }

    override func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        actionButton.addTarget(target, action: action, for: controlEvents)
    }
}

fileprivate class HasNoTokenView: UIControl {

    private (set) var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private let chevronImageView: UIImageView = {
        let imageView = UIImageView(image: R.image.chevronDown())
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        addSubview(titleLabel)
        addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),

            widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            heightAnchor.constraint(equalToConstant: 40),

            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            chevronImageView.widthAnchor.constraint(equalToConstant: 15),
            chevronImageView.heightAnchor.constraint(equalToConstant: 15),
        ])

        backgroundColor = .black
        cornerRadius = 20
        titleLabel.attributedText = NSAttributedString.init(string: "Select Token", attributes: [
            .font: Fonts.bold(size: 17),
            .foregroundColor: Colors.appWhite
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        return nil
    }
}
