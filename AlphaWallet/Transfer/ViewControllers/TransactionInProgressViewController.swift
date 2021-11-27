//
//  TransactionInProgressViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.07.2020.
//

import UIKit
import MBProgressHUD

protocol TransactionInProgressViewControllerDelegate: AnyObject {
    func transactionInProgressDidDismiss(in controller: TransactionInProgressViewController)
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
    
    private lazy var addressContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = viewModel.addressBackgroundColor
        v.isUserInteractionEnabled = true
        return v
    }()

    private lazy var addressLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = viewModel.addressLabelColor
        label.font = viewModel.addressFont
        label.text = viewModel.myAddressText
        label.textAlignment = .center
        label.numberOfLines = 0

        return label
    }()
    private let copyAddressButton = UIButton(type: .system)

    weak var delegate: TransactionInProgressViewControllerDelegate?

    init(viewModel: TransactionInProgressViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem.closeBarButton(self, selector: #selector(dismiss))

        let addressStackView = [.spacerWidth(7), addressLabel, .spacerWidth(10), copyAddressButton, .spacerWidth(7)].asStackView(axis: .horizontal)
        addressStackView.addSubview(forBackgroundColor: viewModel.addressBackgroundColor)
        addressStackView.translatesAutoresizingMaskIntoConstraints = false
        addressContainerView.addSubview(addressStackView)
        addressContainerView.translatesAutoresizingMaskIntoConstraints = false
        copyAddressButton.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)
        copyAddressButton.setContentHuggingPriority(.required, for: .horizontal)
        
        view.addSubview(footerBar)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(imageView)
        view.addSubview(addressContainerView)

        addressContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyAddress)))

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: ScreenChecker().isNarrowScreen ? 20 : 30),

            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: ScreenChecker().isNarrowScreen ? 10 : 79),
            addressStackView.anchorsConstraint(to: addressContainerView, edgeInsets: .init(top: 14, left: 20, bottom: 14, right: 20)),

            addressContainerView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: ScreenChecker().isNarrowScreen ? 10 : 53),
            addressContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            addressContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: addressContainerView.bottomAnchor, constant: 26),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
            copyAddressButton.widthAnchor.constraint(equalToConstant: 30),

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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addressContainerView.cornerRadius = addressContainerView.frame.size.height / 2
    }

    private func configure(viewModel: TransactionInProgressViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        titleLabel.attributedText = viewModel.titleAttributedText
        subtitleLabel.attributedText = viewModel.subtitleAttributedText
        imageView.image = viewModel.image
        copyAddressButton.setImage(R.image.copy(), for: .normal)
        copyAddressButton.tintColor = Colors.headerThemeColor
    }

    @objc private func dismiss(_ sender: UIBarButtonItem) {
        delegate?.transactionInProgressDidDismiss(in: self)
    }

    @objc private func okButtonSelected(_ sender: UIButton) {
        delegate?.controller(self, okButtonSelected: sender)
    }
    
    @objc func copyAddress() {
        UIPasteboard.general.string = viewModel.myAddressText
        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = .text
        hud.label.text = viewModel.addressCopiedText
        hud.hide(animated: true, afterDelay: 1.5)
        showFeedback()
    }
    
    private func showFeedback() {
        UINotificationFeedbackGenerator.show(feedbackType: .success)
    }

}
