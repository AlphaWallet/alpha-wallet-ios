//
//  WalletConnectToSessionViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit
import Combine

protocol WalletConnectToSessionViewControllerDelegate: AnyObject {
    func controller(_ controller: WalletConnectToSessionViewController, continueButtonTapped sender: UIButton)
    func changeConnectionServerSelected(in controller: WalletConnectToSessionViewController)
    func didInvalidateLayout(in controller: WalletConnectToSessionViewController)
    func didClose(in controller: WalletConnectToSessionViewController)
}

class WalletConnectToSessionViewController: UIViewController {
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
    private let buttonsBar = HorizontalButtonsBar(configuration: .custom(types: []))
    private var viewModel: WalletConnectToSessionViewModel

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

    weak var delegate: WalletConnectToSessionViewControllerDelegate?

    init(viewModel: WalletConnectToSessionViewModel) {
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

    func configure(for viewModel: WalletConnectToSessionViewModel) {
        self.viewModel = viewModel

        containerView.scrollView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.title

        buttonsBar.configure(.custom(types: [.secondary, .primary]))
        headerView.iconImageView.setImage(url: viewModel.connectionIconUrl, placeholder: R.image.walletConnectIcon())

        let button1 = buttonsBar.buttons[1]
        button1.shrinkBorderColor = Colors.loadingIndicatorBorder
        button1.setTitle(viewModel.connectionButtonTitle, for: .normal)
        button1.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

        let button2 = buttonsBar.buttons[0]
        button2.shrinkBorderColor = Colors.loadingIndicatorBorder
        button2.setTitle(viewModel.rejectionButtonTitle, for: .normal)
        button2.addTarget(self, action: #selector(closeButtonSelected), for: .touchUpInside)
    }

    @objc private func confirmButtonTapped(_ sender: UIButton) {
        delegate?.controller(self, continueButtonTapped: sender)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func generateSubviews() {
        containerView.stackView.removeAllArrangedSubviews()

        var views: [UIView] = []
        for (sectionIndex, section) in viewModel.sections.enumerated() {
            let header = TransactionConfirmationHeaderView(viewModel: viewModel.headerViewModel(section: sectionIndex))
            header.delegate = self
            var children: [UIView] = []

            switch section {
            case .networks:
                if viewModel.allowChangeConnectionServer {
                    header.enableTapAction(title: R.string.localizable.editButtonTitle())
                }

                for (rowIndex, server) in viewModel.serversToConnect.enumerated() {
                    let view = TransactionConfirmationRPCServerInfoView(viewModel: .init(server: server))
                    view.isHidden = !viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)

                    children.append(view)
                }
            case .name, .url:
                break
            case .methods:
                for (rowIndex, method) in viewModel.methods.enumerated() {
                    let view = TransactionConfirmationRowInfoView(viewModel: .init(title: method, subtitle: nil))
                    view.isHidden = !viewModel.isSubviewsHidden(section: sectionIndex, row: rowIndex)

                    children.append(view)
                }
            }

            header.childrenStackView.addArrangedSubviews(children)
            header.childrenStackView.isHidden = children.isEmpty

            views.append(header)
        }

        containerView.stackView.addArrangedSubviews(views)
    }
}

extension WalletConnectToSessionViewController: TransactionConfirmationHeaderViewDelegate {

    func headerView(_ header: TransactionConfirmationHeaderView, shouldHideChildren section: Int, index: Int) -> Bool {
        return true
    }

    func headerView(_ header: TransactionConfirmationHeaderView, shouldShowChildren section: Int, index: Int) -> Bool {
        return viewModel.isSubviewsHidden(section: section, row: index)
    }

    func headerView(_ header: TransactionConfirmationHeaderView, openStateChanged section: Int) {
        switch viewModel.showHideSection(section) {
        case .show:
            header.expand()
        case .hide:
            header.collapse()
        }

        UIView.animate(withDuration: 0.35) {
            self.view.layoutIfNeeded()
            self.delegate?.didInvalidateLayout(in: self)
        }
    }

    func headerView(_ header: TransactionConfirmationHeaderView, tappedSection section: Int) {
        delegate?.changeConnectionServerSelected(in: self)
    }
}
