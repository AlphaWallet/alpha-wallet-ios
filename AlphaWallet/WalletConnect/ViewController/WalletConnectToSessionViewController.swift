//
//  WalletConnectToSessionViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit

protocol WalletConnectToSessionViewControllerDelegate: AnyObject {
    func controller(_ controller: WalletConnectToSessionViewController, continueButtonTapped sender: UIButton)
    func changeConnectionServerSelected(in controller: WalletConnectToSessionViewController)

    func didClose(in controller: WalletConnectToSessionViewController)
}

class WalletConnectToSessionViewController: UIViewController {
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
    private let buttonsBar = ButtonsBar(configuration: .custom(types: []))
    private var viewModel: WalletConnectToSessionViewModel

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        return scrollView
    }()

    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()

        return view
    }()

    private var contentSizeObservation: NSKeyValueObservation?

    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = viewModel.footerBackgroundColor
        view.addSubview(buttonsBar)

        return view
    }()

    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissViewController))
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(tap)

        return view
    }()

    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white

        view.addSubview(scrollView)
        view.addSubview(footerBar)
        view.addSubview(headerView)
        view.addSubview(separatorLine)

        return view
    }()

    private lazy var heightConstraint: NSLayoutConstraint = {
        return containerView.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()

    private lazy var bottomConstraint: NSLayoutConstraint = {
        containerView.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }()

    private var allowPresentationAnimation: Bool = true
    private var allowDismissalAnimation: Bool = true

    weak var delegate: WalletConnectToSessionViewControllerDelegate?

    init(viewModel: WalletConnectToSessionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(backgroundView)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            backgroundView.bottomAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            heightConstraint,
            bottomConstraint,
            containerView.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            separatorLine.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.separatorHeight),
            separatorLine.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),

            footerBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TransactionConfirmation.footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor),

            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
        ])
        headerView.closeButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)

        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .initial]) { [weak self] scrollView, _ in
            guard let strongSelf = self, strongSelf.allowDismissalAnimation else { return }

            let statusBarHeight = UIApplication.shared.firstKeyWindow?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
            let contentHeight = scrollView.contentSize.height + DataEntry.Metric.TransactionConfirmation.footerHeight + DataEntry.Metric.TransactionConfirmation.headerHeight + UIApplication.shared.bottomSafeAreaHeight
            let newHeight = min(UIScreen.main.bounds.height - statusBarHeight, contentHeight)

            let fillScreenPercentage = strongSelf.heightConstraint.constant / strongSelf.view.bounds.height

            if fillScreenPercentage >= 0.9 {
                strongSelf.heightConstraint.constant = strongSelf.containerView.bounds.height
            } else {
                strongSelf.heightConstraint.constant = newHeight
            }
        }

        generateSubviews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(for: viewModel)

        //NOTE: to display animation correctly we can take 'view.frame.height' and bottom view will smoothly slide up from button ;)
        bottomConstraint.constant = view.frame.height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(true, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presentViewAnimated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(false, animated: false)
        }
    }

    private func presentViewAnimated() {
        guard allowPresentationAnimation else { return }
        allowPresentationAnimation = false

        bottomConstraint.constant = 0

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    func dismissViewAnimated(with completion: @escaping () -> Void) {
        guard allowDismissalAnimation else { return }
        allowDismissalAnimation = false

        bottomConstraint.constant = heightConstraint.constant

        UIView.animate(withDuration: 0.4, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            completion()
        })
    }

    @objc private func dismissViewController() {
        delegate?.didClose(in: self)
    }

    func reloadView() {
        generateSubviews()
    }

    func configure(for viewModel: WalletConnectToSessionViewModel) {
        self.viewModel = viewModel

        scrollView.backgroundColor = viewModel.backgroundColor
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
        button2.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)
    }

    @objc private func confirmButtonTapped(_ sender: UIButton) {
        delegate?.controller(self, continueButtonTapped: sender)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func generateSubviews() {
        stackView.removeAllArrangedSubviews()

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

        stackView.addArrangedSubviews(views)
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
        }
    }

    func headerView(_ header: TransactionConfirmationHeaderView, tappedSection section: Int) {
        delegate?.changeConnectionServerSelected(in: self)
    }
}
