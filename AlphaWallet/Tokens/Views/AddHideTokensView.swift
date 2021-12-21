// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol AddHideTokensViewDelegate: AnyObject {
    func view(_ view: AddHideTokensView, didSelectAddHideTokensButton sender: UIButton)
}

class AddHideTokensView: UIView, ReusableTableHeaderViewType {
    private let addTokenTitleLeftInset: CGFloat = 7
    private lazy var addTokenButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceRightToLeft
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: -addTokenTitleLeftInset, bottom: 0, right: addTokenTitleLeftInset)
        button.addTarget(self, action: #selector(addHideTokensSelected), for: .touchUpInside)

        return button
    }()

    private lazy var badgeIndicatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    private lazy var badgeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "0"
        label.textAlignment = .center
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 14)

        return label
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center

        return label
    }()

    private var badgeText: String? {
        didSet {
            if let value = badgeText, !value.isEmpty {
                badgeLabel.text = value
                badgeIndicatorView.isHidden = false
            } else {
                badgeIndicatorView.isHidden = true
            }
        }
    }

    weak var delegate: AddHideTokensViewDelegate?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(addTokenButton)
        addSubview(badgeIndicatorView)
        badgeIndicatorView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            addTokenButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addTokenButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            badgeIndicatorView.widthAnchor.constraint(greaterThanOrEqualTo: badgeIndicatorView.heightAnchor),
            badgeIndicatorView.centerXAnchor.constraint(equalTo: addTokenButton.trailingAnchor, constant: -2),
            badgeIndicatorView.centerYAnchor.constraint(equalTo: addTokenButton.topAnchor),
            badgeLabel.anchorsConstraint(to: badgeIndicatorView),
        ])

        //NOTE: We add tap gesture to prevent broke layout for 'badgeIndicatorView', because it snapped to buttons top, and we can't set buttons height is equal to superview height.
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        isUserInteractionEnabled = true
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: ShowAddHideTokensViewModel = .init()) {
        backgroundColor = viewModel.backgroundColor
        addTokenButton.setImage(viewModel.addHideTokensIcon, for: .normal)
        addTokenButton.setTitle(viewModel.addHideTokensTitle, for: .normal)
        addTokenButton.setTitleColor(viewModel.addHideTokensTintColor, for: .normal)
        addTokenButton.titleLabel?.font = viewModel.addHideTokensTintFont
        badgeText = viewModel.badgeText
        badgeIndicatorView.backgroundColor = viewModel.badgeBackgroundColor
        titleLabel.attributedText = viewModel.titleAttributedString
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let value = max(badgeIndicatorView.frame.height, badgeIndicatorView.frame.width)
        badgeIndicatorView.layer.cornerRadius = value / 2.0
    }

    @objc private func viewTapped(_ sender: UITapGestureRecognizer) {
        delegate?.view(self, didSelectAddHideTokensButton: addTokenButton)
    }

    @objc private func addHideTokensSelected(_ sender: UIButton) {
        delegate?.view(self, didSelectAddHideTokensButton: sender)
    }
}

