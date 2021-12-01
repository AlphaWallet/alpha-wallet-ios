//
//  WhatsNewViews.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 29/11/21.
//

import UIKit

class WhatsNewHeaderView: UIView {
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = R.font.sourceSansProBold(size: 24.0)
        label.textAlignment = .center
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.heightAnchor.constraint(equalToConstant: 42.0)
        ])
        return label
    }()

    init(title: String) {
        super.init(frame: .zero)
        configureView(title: title)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configureView(title: String) {
        titleLabel.text = title
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

class WhatsNewSubHeaderView: UIView {
    lazy var dotImageView: UIImageView = {
        let image = R.image.oval()
        let view = UIImageView(image: image)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 4.0),
            view.heightAnchor.constraint(equalToConstant: 4.0)
        ])
        return view
    }()
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = R.font.sourceSansProSemibold(size: 20.0)
        label.textAlignment = .center
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    init(title: String) {
        super.init(frame: .zero)
        configureView(title: title)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configureView(title: String) {
        titleLabel.text = title
        addSubview(dotImageView)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            dotImageView.topAnchor.constraint(equalTo: topAnchor, constant: 16.0),
            dotImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotImageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -4.0),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }
}

class WhatsNewEntryView: UIView {
    lazy var tickViewImageView: UIImageView = {
        let image: UIImage? = R.image.iconsSystemBorderCircle()?.imageFlippedForRightToLeftLayoutDirection()
        let view = UIImageView(image: image)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 24.0),
            view.heightAnchor.constraint(equalToConstant: 24.0)
        ])
        return view
    }()
    lazy var entryLabel: UILabel = {
        let label = UILabel()
        label.font = R.font.sourceSansProRegular(size: 20.0)
        label.textAlignment = .natural
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    init(entryString: String, shouldShowCheckmarks: Bool) {
        super.init(frame: .zero)
        configureView(entryString: entryString, shouldShowCheckmarks: shouldShowCheckmarks)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configureView(entryString: String, shouldShowCheckmarks: Bool) {
        entryLabel.text = entryString
        tickViewImageView.isHidden = !shouldShowCheckmarks
        addSubview(tickViewImageView)
        addSubview(entryLabel)
        NSLayoutConstraint.activate([
            tickViewImageView.topAnchor.constraint(equalTo: topAnchor),
            tickViewImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0),
            tickViewImageView.trailingAnchor.constraint(equalTo: entryLabel.leadingAnchor, constant: -8.0),
            entryLabel.topAnchor.constraint(equalTo: topAnchor),
            entryLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -48.0),
            entryLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8.0)
        ])
    }
}