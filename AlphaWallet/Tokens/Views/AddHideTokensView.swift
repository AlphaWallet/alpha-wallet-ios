// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ShowAddHideTokensViewDelegate: class {
    func view(_ view: ShowAddHideTokensView, didSelectAddHideTokensButton sender: UIButton)
}

class ShowAddHideTokensView: UIView {
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

    weak var delegate: ShowAddHideTokensViewDelegate?

    init() {
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func setupViews() {
        addSubview(addTokenButton)
        addSubview(badgeIndicatorView)
        badgeIndicatorView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            addTokenButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addTokenButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            badgeIndicatorView.widthAnchor.constraint(greaterThanOrEqualTo: badgeIndicatorView.heightAnchor),
            badgeIndicatorView.centerXAnchor.constraint(equalTo: addTokenButton.trailingAnchor, constant: -2),
            badgeIndicatorView.centerYAnchor.constraint(equalTo: addTokenButton.topAnchor),
            badgeLabel.anchorsConstraint(to: badgeIndicatorView)
        ])
    }

    func configure(viewModel: ShowAddHideTokensViewModel) {
        backgroundColor = R.color.alabaster()
        addTokenButton.setImage(viewModel.addHideTokensIcon, for: .normal)
        addTokenButton.setTitle(viewModel.addHideTokensTitle, for: .normal)
        addTokenButton.setTitleColor(viewModel.addHideTokensTintColor, for: .normal)
        addTokenButton.titleLabel?.font = viewModel.addHideTokensTintFont
        badgeText = viewModel.badgeText
        badgeIndicatorView.backgroundColor = viewModel.badgeBackgroundColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let value = max(badgeIndicatorView.frame.height, badgeIndicatorView.frame.width)
        badgeIndicatorView.layer.cornerRadius = value / 2.0
    }

    @objc private func addHideTokensSelected(_ sender: UIButton) {
        delegate?.view(self, didSelectAddHideTokensButton: sender)
    }
}
