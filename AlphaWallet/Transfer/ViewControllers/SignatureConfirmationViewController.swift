//
//  SignConfirmationViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit
import Combine

protocol SignatureConfirmationViewControllerDelegate: AnyObject {
    func controller(_ controller: SignatureConfirmationViewController, continueButtonTapped sender: UIButton)
    func controllerDidTapEdit(_ controller: SignatureConfirmationViewController, for section: Int)
    func didClose(in controller: SignatureConfirmationViewController)
}

class SignatureConfirmationViewController: UIViewController {
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
    private let buttonsBar = HorizontalButtonsBar(configuration: .empty)
    let viewModel: SignatureConfirmationViewModel

    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()

        return view
    }()

    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = viewModel.footerBackgroundColor
        view.addSubview(buttonsBar)

        return view
    }()
    private let containerView = ScrollableStackView()
    private lazy var heightConstraint: NSLayoutConstraint = {
        return view.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: SignatureConfirmationViewControllerDelegate?

    init(viewModel: SignatureConfirmationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(containerView)
        view.addSubview(footerBar)
        view.addSubview(headerView)
        view.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            heightConstraint,
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),

            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            separatorLine.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.separatorHeight),
            separatorLine.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: HorizontalButtonsBar.buttonsHeight)
        ])

        headerView.closeButton.addTarget(self, action: #selector(closeButtonSelected), for: .touchUpInside)

        let scrollView = containerView.scrollView

        scrollView
            .publisher(for: \.contentSize, options: [.new, .initial])
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }

                let statusBarHeight = UIView.statusBarFrame.height
                let contentHeight = scrollView.contentSize.height + DataEntry.Metric.TransactionConfirmation.footerHeight + DataEntry.Metric.TransactionConfirmation.headerHeight
                let newHeight = min(UIScreen.main.bounds.height - statusBarHeight, contentHeight)

                let fillScreenPercentage = strongSelf.heightConstraint.constant / UIScreen.main.bounds.height - statusBarHeight

                if fillScreenPercentage >= 0.9 {
                    strongSelf.heightConstraint.constant = UIScreen.main.bounds.height - statusBarHeight
                } else {
                    strongSelf.heightConstraint.constant = newHeight
                }

            }.store(in: &cancelable)

        generateSubviews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(for: viewModel)
    }

    @objc private func closeButtonSelected() {
        delegate?.didClose(in: self)
    }

    func reloadView() {
        generateSubviews()
    }
    
    private func configure(for viewModel: SignatureConfirmationViewModel) {
        containerView.scrollView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor

        headerView.iconImageView.setImage(url: viewModel.iconUrl, placeholder: viewModel.placeholderIcon)
        buttonsBar.configure(.custom(types: [.primary, .secondary]))

        let button1 = buttonsBar.buttons[0]
        button1.shrinkBorderColor = Colors.loadingIndicatorBorder
        button1.setTitle(viewModel.confirmationButtonTitle, for: .normal)
        button1.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

        let button2 = buttonsBar.buttons[1]
        button2.shrinkBorderColor = Colors.loadingIndicatorBorder
        button2.setTitle(viewModel.cancelationButtonTitle, for: .normal)
        button2.addTarget(self, action: #selector(closeButtonSelected), for: .touchUpInside)
    }

    @objc private func confirmButtonTapped(_ sender: UIButton) {
        delegate?.controller(self, continueButtonTapped: sender)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension SignatureConfirmationViewController {

    private func generateSubviews() {
        containerView.stackView.removeAllArrangedSubviews()

        var views: [UIView] = []

        for each in viewModel.viewModels {
            switch each {
            case .header(let headerViewModel):
                let header = TransactionConfirmationHeaderView(viewModel: headerViewModel)
                header.delegate = self

                views.append(header)
            case .headerWithShowButton(let headerViewModel, let availableToShowFullMessage):
                let header = TransactionConfirmationHeaderView(viewModel: headerViewModel)
                header.delegate = self

                if availableToShowFullMessage {
                    header.enableTapAction(title: "Show")
                }

                views.append(header)
            }
        }

        containerView.stackView.addArrangedSubviews(views)
    }
}

extension SignatureConfirmationViewController: TransactionConfirmationHeaderViewDelegate {

    func headerView(_ header: TransactionConfirmationHeaderView, shouldHideChildren section: Int, index: Int) -> Bool {
        return true
    }

    func headerView(_ header: TransactionConfirmationHeaderView, shouldShowChildren section: Int, index: Int) -> Bool {
        return false
    }

    func headerView(_ header: TransactionConfirmationHeaderView, openStateChanged section: Int) {
        //no op
    }

    func headerView(_ header: TransactionConfirmationHeaderView, tappedSection section: Int) {
        delegate?.controllerDidTapEdit(self, for: section)
    }
}
