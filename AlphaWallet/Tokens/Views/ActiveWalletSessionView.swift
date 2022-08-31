//
//  ActiveWalletSessionView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.10.2020.
//

import UIKit
import AlphaWalletFoundation

protocol ActiveWalletSessionViewDelegate: AnyObject {
    func view(_ view: ActiveWalletSessionView, didSelectTap sender: UITapGestureRecognizer)
}

struct ActiveWalletSessionViewModel {
    let count: Int
    let backgroundColor: UIColor = Configuration.Color.Semantic.tableViewSpecialBackground
    let icon: UIImage = R.image.walletConnectIcon()!

    var titleAttributedText: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .left

        return .init(string: "WalletConnect", attributes: [
            .paragraphStyle: style,
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 18 : 20) as Any,
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    var descriptionAttributedText: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        let title: String
        if count == 1 {
            title = R.string.localizable.walletConnectActiveSessions()
        } else {
            title = R.string.localizable.walletConnectActiveSessionsPlural()
        }
        return .init(string: title, attributes: [
            .paragraphStyle: style,
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 14 : 16) as Any,
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
        ])
    }
}

enum SeparatorViewPlacement: Int {
    case top
    case bottom
}

class SeparatorView: UIView {

    init() {
        super.init(frame: .zero)

        backgroundColor = R.color.mercury()
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func add(to view: UIView, _ placement: SeparatorViewPlacement) {
        view.addSubview(self)

        let anchor: NSLayoutConstraint
        switch placement {
        case .bottom:
            anchor = bottomAnchor.constraint(equalTo: view.bottomAnchor)
        case .top:
            anchor = topAnchor.constraint(equalTo: view.topAnchor)
        }

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightAnchor.constraint(equalToConstant: 0.7),
            anchor
        ])
    }
}

class ActiveWalletSessionView: UITableViewHeaderFooterView {

    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    private let background = UIView()
    private let separators = (top: SeparatorView(), bottom: SeparatorView())

    weak var delegate: ActiveWalletSessionViewDelegate?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        let col1 = [titleLabel, descriptionLabel].asStackView(axis: .vertical, spacing: 5)
        let stackView = [iconImageView, col1].asStackView(spacing: 12, alignment: .center)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            iconImageView.widthAnchor.constraint(equalToConstant: 40).set(priority: .defaultHigh),

            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 16, left: 20, bottom: 16, right: 16)).map { $0.set(priority: .defaultHigh) },
            background.anchorsConstraint(to: contentView)
        ])

        separators.top.add(to: background, .top)

        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        contentView.isUserInteractionEnabled = true
        contentView.addGestureRecognizer(tap)
    }

    @objc private func viewTapped(_ sender: UITapGestureRecognizer) {
        delegate?.view(self, didSelectTap: sender)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: ActiveWalletSessionViewModel) {
        background.backgroundColor = viewModel.backgroundColor

        iconImageView.image = viewModel.icon
        titleLabel.attributedText = viewModel.titleAttributedText
        descriptionLabel.attributedText = viewModel.descriptionAttributedText
    }
}
