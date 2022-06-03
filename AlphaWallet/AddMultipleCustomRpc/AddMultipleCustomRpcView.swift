//
//  AddMultipleCustomRpcView.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 30/12/21.
//

import UIKit

class AddMultipleCustomRpcView: UIView {

    // MARK: - Properties
    // MARK: Public

    var chainNameString: String = ""
    var progressString: String = ""
    var progress: Float = 0.0

    // MARK: - User Interface Elements

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = Fonts.bold(size: 17)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var activityIndicatorView: UIActivityIndicatorView = {
        let view: UIActivityIndicatorView
        view = UIActivityIndicatorView(style: .medium)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.hidesWhenStopped = false
        return view
    }()

    private lazy var networkNameLabel: UILabel = {
        let label = UILabel()
        label.font = Fonts.regular(size: 15)
        label.text = "…"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var progressIndicatorView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.font = Fonts.regular(size: 15)
        label.text = "-"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(R.string.localizable.cancel(), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Constructors

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    private func configureView() {
        configureTitleLabel()
        configureActivityIndicator()
        configureNetworkNameLabel()
        configureProgressLabel()
        configureButton()
        backgroundColor = R.color.alabaster()!
        layer.cornerRadius = 25.0
    }

    private func configureTitleLabel() {
        titleLabel.text = R.string.localizable.addMultipleCustomRpcTitle()
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalToSystemSpacingBelow: topAnchor, multiplier: 1.0),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    private func configureActivityIndicator() {
        addSubview(activityIndicatorView)
        NSLayoutConstraint.activate([
            activityIndicatorView.topAnchor.constraint(equalToSystemSpacingBelow: titleLabel.bottomAnchor, multiplier: 2.0),
            activityIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    private func configureNetworkNameLabel() {
        addSubview(networkNameLabel)
        NSLayoutConstraint.activate([
            networkNameLabel.topAnchor.constraint(equalToSystemSpacingBelow: activityIndicatorView.bottomAnchor, multiplier: 1.0),
            networkNameLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier: 4.0),
            trailingAnchor.constraint(equalToSystemSpacingAfter: networkNameLabel.trailingAnchor, multiplier: 4.0),
        ])
    }

    private func configureProgressLabel() {
        addSubview(progressLabel)
        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalToSystemSpacingBelow: networkNameLabel.bottomAnchor, multiplier: 1.0),
            progressLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    private func configureButton() {
        addSubview(cancelButton)
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalToSystemSpacingBelow: progressLabel.bottomAnchor, multiplier: 4.0),
            bottomAnchor.constraint(equalToSystemSpacingBelow: cancelButton.bottomAnchor, multiplier: 1.0),
            cancelButton.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    // MARK: - Public interface

    func addCancelButtonTarget(_ target: Any?, action: Selector) {
        cancelButton.addTarget(target, action: action, for: .touchUpInside)
    }

    func startActivityIndicator() {
        activityIndicatorView.startAnimating()
    }

    func stopActivityIndicator() {
        activityIndicatorView.stopAnimating()
    }

    func update() {
        networkNameLabel.text = chainNameString
        progressLabel.text = progressString
        progressIndicatorView.setProgress(progress, animated: true)
    }

}
