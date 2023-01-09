//
//  AcceptProposalViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.02.2021.
//

import UIKit
import Combine

protocol AcceptProposalViewControllerDelegate: AnyObject {
    func controller(_ controller: AcceptProposalViewController, continueButtonTapped sender: UIButton)
    func changeConnectionServerSelected(in controller: AcceptProposalViewController)
    func didInvalidateLayout(in controller: AcceptProposalViewController)
    func didClose(in controller: AcceptProposalViewController)
}

class AcceptProposalViewController: UIViewController {
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: viewModel.title))
    private let buttonsBar = HorizontalButtonsBar(configuration: .empty)
    private (set) var viewModel: AcceptProposalViewModel
    private let separator = UIView.separator()

    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = Configuration.Color.Semantic.backgroundClear
        view.addSubview(buttonsBar)

        return view
    }()
    private let containerView = ScrollableStackView()
    private lazy var heightConstraint: NSLayoutConstraint = {
        return view.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: AcceptProposalViewControllerDelegate?

    init(viewModel: AcceptProposalViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(containerView)
        view.addSubview(footerBar)
        view.addSubview(headerView)
        view.addSubview(separator)

        NSLayoutConstraint.activate([
            heightConstraint,
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.topAnchor.constraint(equalTo: view.topAnchor),

            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            separator.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),

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

        containerView.scrollView.backgroundColor = Configuration.Color.Semantic.backgroundClear
        view.backgroundColor = Configuration.Color.Semantic.backgroundClear

        configure(for: viewModel)
    }

    func reloadView() {
        generateSubviews()
    }

    private func configure(for viewModel: AcceptProposalViewModel) {
        buttonsBar.configure(.custom(types: [.primary, .secondary]))
        headerView.iconImageView.setImage(url: viewModel.connectionIconUrl, placeholder: R.image.walletConnectIcon())

        let button1 = buttonsBar.buttons[0]
        button1.shrinkBorderColor = Configuration.Color.Semantic.loadingIndicatorBorder
        button1.setTitle(viewModel.connectButtonTitle, for: .normal)
        button1.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

        let button2 = buttonsBar.buttons[1]
        button2.shrinkBorderColor = Configuration.Color.Semantic.loadingIndicatorBorder
        button2.setTitle(viewModel.rejectButtonTitle, for: .normal)
        button2.addTarget(self, action: #selector(closeButtonSelected), for: .touchUpInside)
    }

    @objc private func closeButtonSelected() {
        delegate?.didClose(in: self)
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

        var currentHeader: TransactionConfirmationHeaderView?

        for each in viewModel.viewModels {
            switch each {
            case .header(let viewModel, let editButtonEnabled):
                let header = TransactionConfirmationHeaderView(viewModel: viewModel)
                if editButtonEnabled {
                    header.enableTapAction(title: R.string.localizable.editButtonTitle())
                }

                header.delegate = self
                currentHeader = header

                views.append(header)
            case .serverField(let viewModel, let isHidden):
                let view = TransactionConfirmationRPCServerInfoView(viewModel: viewModel)
                view.isHidden = isHidden

                currentHeader?.childrenStackView.addArrangedSubview(view)
                currentHeader?.childrenStackView.isHidden = currentHeader?.childrenStackView.arrangedSubviews.isEmpty ?? true
            case .anyField(let viewModel, let isHidden):
                let view = TransactionConfirmationRowInfoView(viewModel: viewModel)
                view.isHidden = isHidden

                currentHeader?.childrenStackView.addArrangedSubview(view)
                currentHeader?.childrenStackView.isHidden = currentHeader?.childrenStackView.arrangedSubviews.isEmpty ?? true
            }
        }

        containerView.stackView.addArrangedSubviews(views)
    }
}

extension AcceptProposalViewController: TransactionConfirmationHeaderViewDelegate {

    func headerView(_ header: TransactionConfirmationHeaderView, shouldHideChildren section: Int, index: Int) -> Bool {
        return true
    }

    func headerView(_ header: TransactionConfirmationHeaderView, shouldShowChildren section: Int, index: Int) -> Bool {
        return viewModel.isSubviewsHidden(section: section, row: index)
    }

    func headerView(_ header: TransactionConfirmationHeaderView, openStateChanged section: Int) {
        switch viewModel.expandOrCollapseAction(for: section) {
        case .expand: header.expand()
        case .collapse: header.collapse()
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
