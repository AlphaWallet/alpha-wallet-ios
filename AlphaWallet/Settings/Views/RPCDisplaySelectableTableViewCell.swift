//
//  ServerImageTableViewCell.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 18/4/22.
//

import UIKit
import AlphaWalletFoundation

class RPCDisplaySelectableTableViewCell: UITableViewCell {

    // MARK: - Properties

    // MARK: Private
    private let chainIconView: ImageView = {
        let imageView = ImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 40.0),
            imageView.heightAnchor.constraint(equalToConstant: 40.0),
        ])

        return imageView
    }()
    private let accessoryImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 30.0),
            imageView.heightAnchor.constraint(equalToConstant: 30.0),
        ])
        return imageView
    }()
    private let warningImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 25.0),
            imageView.heightAnchor.constraint(equalToConstant: 25.0),
        ])
        return imageView
    }()
    private let infoView: ServerInformationView = ServerInformationView()
    private let topSeparator: UIView = UIView.spacer(backgroundColor: Configuration.Color.Semantic.tableViewSeparator)
    private lazy var unavailableToSelectView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = (Configuration.Color.Semantic.defaultViewBackground).withAlphaComponent(0.4)
        view.isHidden = false

        return view
    }()
    // MARK: - Initializers

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        constructView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: - Configuration and Construction

    override func prepareForReuse() {
        super.prepareForReuse()
        chainIconView.image = nil
    }

    // MARK: Public

    func configure(viewModel: ServerImageTableViewCellViewModelType) {
        configureView(viewModel: viewModel)
        configureChainIconView(viewModel: viewModel)
        configureInfoView(viewModel: viewModel)
        accessoryImageView.image = viewModel.accessoryImage
        unavailableToSelectView.isHidden = viewModel.isAvailableToSelect
        warningImageView.image = viewModel.warningImage
        warningImageView.isHidden = viewModel.warningImage == nil
    }

    // MARK: Private

    private func constructView() {
        addSubview(topSeparator)
        addSubview(chainIconView)
        addSubview(infoView)
        addSubview(unavailableToSelectView)

        let accessoryStackView = [warningImageView, accessoryImageView].asStackView(axis: .horizontal, spacing: 10, alignment: .center)
        accessoryStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accessoryStackView)

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: contentView.topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            chainIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0),
            chainIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chainIconView.topAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: topAnchor, multiplier: 1.0),
            chainIconView.bottomAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: bottomAnchor, multiplier: 1.0),

            infoView.leadingAnchor.constraint(equalTo: chainIconView.trailingAnchor, constant: 16.0),
            infoView.trailingAnchor.constraint(equalTo: accessoryStackView.leadingAnchor),
            infoView.centerYAnchor.constraint(equalTo: centerYAnchor),
            infoView.topAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: topAnchor, multiplier: 1.0),
            infoView.bottomAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: bottomAnchor, multiplier: 1.0),

            accessoryStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            accessoryStackView.topAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: topAnchor, multiplier: 1.0),
            accessoryStackView.bottomAnchor.constraint(lessThanOrEqualToSystemSpacingBelow: bottomAnchor, multiplier: 1.0),
            accessoryStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20.0),

            unavailableToSelectView.anchorsConstraint(to: self)
        ])
    }

    private func configureView(viewModel: ServerImageTableViewCellViewModelType) {
        selectionStyle = viewModel.selectionStyle
        backgroundColor = viewModel.backgroundColor
        topSeparator.isHidden = viewModel.isTopSeparatorHidden
    }

    private func configureChainIconView(viewModel: ServerImageTableViewCellViewModelType) {
        switch viewModel.server {
        case .auto:
            chainIconView.image = R.image.launch_icon()!
        case .server(let server):
            chainIconView.set(imageSource: server.walletConnectIconImage)
        }
    }

    private func configureInfoView(viewModel: ServerImageTableViewCellViewModelType) {
        infoView.configure(viewModel: viewModel)
    }
}

// MARK: - private class

private class ServerInformationView: UIView {

    // MARK: - Properties

    // MARK: Private
    private let primaryTextLabel: UILabel = UILabel()
    private let secondaryTextLabel: UILabel = UILabel()

    // MARK: - Initializers

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        constructView()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    // MARK: - Configuration and Construction

    // MARK: Public

    func configure(viewModel: ServerImageTableViewCellViewModelType) {
        primaryTextLabel.font = viewModel.primaryFont
        primaryTextLabel.text = viewModel.primaryText
        primaryTextLabel.textColor = viewModel.primaryFontColor
        secondaryTextLabel.font = viewModel.secondaryFont
        secondaryTextLabel.text = viewModel.secondaryText
        secondaryTextLabel.textColor = viewModel.secondaryFontColor
    }

    // MARK: Private
    
    private func constructView() {
        primaryTextLabel.translatesAutoresizingMaskIntoConstraints = false
        secondaryTextLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryTextLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        secondaryTextLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        addSubview(primaryTextLabel)
        addSubview(secondaryTextLabel)
        NSLayoutConstraint.activate([
            primaryTextLabel.topAnchor.constraint(equalTo: topAnchor),
            primaryTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            primaryTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            primaryTextLabel.bottomAnchor.constraint(equalTo: secondaryTextLabel.topAnchor),
            secondaryTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            secondaryTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            secondaryTextLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

class RPCDisplayTableViewCell: RPCDisplaySelectableTableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
