//
//  TransactionInProgressViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.07.2020.
//

import UIKit

protocol TransactionInProgressViewControllerDelegate: class {
    func transactionInProgressDidDissmiss(in controller: TransactionInProgressViewController)
    func controller(_ controller: TransactionInProgressViewController, okButtonSelected sender: UIButton)
}

class TransactionInProgressViewController: UIViewController {

    private let viewModel: TransactionInProgressViewModel
    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.addSubview(buttonsBar)
        return view
    }()
    private lazy var buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    weak var delegate: TransactionInProgressViewControllerDelegate?

    init(viewModel: TransactionInProgressViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem.closeBarButton(self, selector: #selector(dissmiss))

        view.addSubview(footerBar)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ScreenChecker().isNarrowScreen ? 20 : 30),

            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: ScreenChecker().isNarrowScreen ? 10 : 50),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -30),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.setTitle(viewModel.okButtonTitle, for: .normal)
        button.addTarget(self, action: #selector(okButtonSelected), for: .touchUpInside)

        configure(viewModel: viewModel)
    }

    private func configure(viewModel: TransactionInProgressViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        titleLabel.attributedText = viewModel.titleAttributedText
        subtitleLabel.attributedText = viewModel.subtitleAttributedText
        imageView.image = viewModel.image
    }

    @objc private func dissmiss(_ sender: UIBarButtonItem) {
        delegate?.transactionInProgressDidDissmiss(in: self)
    }

    @objc private func okButtonSelected(_ sender: UIButton) {
        delegate?.controller(self, okButtonSelected: sender)
    }
}

extension UIBarButtonItem {
    static func closeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(
            image: R.image.close(),
            style: .done,
            target: target,
            action: selector
        )
    }
}
