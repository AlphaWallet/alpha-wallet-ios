// Copyright DApps Platform Inc. All rights reserved.

import UIKit

protocol BrowserErrorViewDelegate: AnyObject {
    func didTapReload(_ sender: Button)
}

final class BrowserErrorView: UIView {
    private let topMargin: CGFloat = 120
    private let leftMargin: CGFloat = 40
    private let buttonTopMargin: CGFloat = 6

    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = Configuration.Color.Semantic.alternativeText
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var reloadButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        button.setTitle(R.string.localizable.browserReloadButtonTitle(), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.sizeToFit()
        return button
    }()

    weak var delegate: BrowserErrorViewDelegate?

    init() {
        super.init(frame: CGRect.zero)
        finishInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        finishInit()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(error: Error) {
        isHidden = false
        textLabel.text = error.localizedDescription
        textLabel.textAlignment = .center
        textLabel.setNeedsLayout()
    }

    @objc func reloadTapped() {
        delegate?.didTapReload(reloadButton)
    }

    private func finishInit() {
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        addSubview(textLabel)
        addSubview(reloadButton)
        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leftMargin),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -leftMargin),
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: topMargin),

            reloadButton.centerXAnchor.constraint(equalTo: textLabel.centerXAnchor),
            reloadButton.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: buttonTopMargin),
        ])
    }
}
