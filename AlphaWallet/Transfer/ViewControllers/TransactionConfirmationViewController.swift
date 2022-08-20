// Copyright © 2020 Stormbird PTE. LTD.

import BigInt
import Foundation
import UIKit
import Combine

protocol TransactionConfirmationViewControllerDelegate: AnyObject {
    func controller(_ controller: TransactionConfirmationViewController, continueButtonTapped sender: UIButton)
    func controllerDidTapEdit(_ controller: TransactionConfirmationViewController)
    func didClose(in controller: TransactionConfirmationViewController)
    func didInvalidateLayout(in controller: TransactionConfirmationViewController)
}

class TransactionConfirmationViewController: UIViewController {
    enum State {
        case ready
        case pending
        case done(withError: Bool)
    }

    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private let viewModel: TransactionConfirmationViewModel
    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()
        return view
    }()
    private let loadingIndicatorView = ActivityIndicatorControl()
    private lazy var footerBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = viewModel.footerBackgroundColor
        view.addSubview(buttonsBar)
        view.addSubview(loadingIndicatorView)

        return view
    }()
    private let containerView = ScrollableStackView()
    private lazy var heightConstraint: NSLayoutConstraint = {
        return view.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
    }()

    private var cancelable = Set<AnyCancellable>()

    weak var delegate: TransactionConfirmationViewControllerDelegate?

    init(viewModel: TransactionConfirmationViewModel) {
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
            buttonsBar.heightAnchor.constraint(equalToConstant: HorizontalButtonsBar.buttonsHeight),

            loadingIndicatorView.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            loadingIndicatorView.centerXAnchor.constraint(equalTo: footerBar.centerXAnchor)
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
    } 
    
    override func viewDidLoad() {
        super.viewDidLoad()

        set(state: .ready)
        bind(for: viewModel)
    }

    func set(state: State, completion: (() -> Void)? = nil) {
        let confirmationButton = buttonsBar.buttons[0]
        switch state {
        case .ready:
            buttonsBar.isHidden = false
            loadingIndicatorView.isHidden = true
        case .pending:
            confirmationButton.startAnimation(completion: { [weak self] in
                self?.buttonsBar.isHidden = true
                self?.loadingIndicatorView.isHidden = false
                self?.loadingIndicatorView.startAnimating()
            })
        case .done(let hasError):
            buttonsBar.isHidden = true
            loadingIndicatorView.isHidden = false
            loadingIndicatorView.stopAnimating(completion: { [weak self] in
                self?.buttonsBar.isHidden = false
                self?.loadingIndicatorView.isHidden = true
                let animationStyle: StopAnimationStyle = {
                    if hasError {
                        return .shake
                    } else {
                        return .normal
                    }
                }()
                confirmationButton.stopAnimation(animationStyle: animationStyle, completion: completion)
            })
        }
    }

    @objc private func closeButtonSelected(_ sender: UIButton) {
        delegate?.didClose(in: self)
    }

    private func bind(for viewModel: TransactionConfirmationViewModel) {
        containerView.scrollView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.title

        separatorLine.isHidden = !viewModel.hasSeparatorAboveConfirmButton

        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.shrinkBorderColor = Colors.loadingIndicatorBorder
        button.setTitle(viewModel.confirmationButtonTitle, for: .normal)
        button.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

        viewModel.views
            .sink { [weak self] views in
                self?.generateSubviews(for: views)
            }.store(in: &cancelable)
    }

    @objc func confirmButtonTapped(_ sender: UIButton) {
        guard viewModel.canBeConfirmed else { return }
        delegate?.controller(self, continueButtonTapped: sender)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension TransactionConfirmationViewController {

    private func generateSubviews(for views: [TransactionConfirmationViewModel.ViewType]) {
        containerView.stackView.removeAllArrangedSubviews()

        var activeHeaderView: TransactionConfirmationHeaderView?

        for each in views {
            switch each {
            case .view(let viewModel, let isHidden):
                let view = TransactionConfirmationRowInfoView(viewModel: viewModel)
                view.isHidden = isHidden

                activeHeaderView?.childrenStackView.addArrangedSubview(view)
            case .separator(let height):
                let view: UIView = UIView.spacer(height: height)

                activeHeaderView?.childrenStackView.addArrangedSubview(view)
            case .details(let viewModel):
                let view = TransactionConfirmationRowDescriptionView(viewModel: viewModel)

                activeHeaderView?.childrenStackView.addArrangedSubview(view)
            case .header(let viewModel, let isEditEnabled):
                let header = TransactionConfirmationHeaderView(viewModel: viewModel)
                header.delegate = self
                if isEditEnabled {
                    header.enableTapAction(title: R.string.localizable.editButtonTitle())
                }

                containerView.stackView.addArrangedSubview(header)
                activeHeaderView = header
            }

            activeHeaderView?.childrenStackView.isHidden = activeHeaderView?.childrenStackView.arrangedSubviews.isEmpty ?? true
        }
    }
}

extension TransactionConfirmationViewController: TransactionConfirmationHeaderViewDelegate {

    func headerView(_ header: TransactionConfirmationHeaderView, shouldHideChildren section: Int, index: Int) -> Bool {
        return true
    }

    func headerView(_ header: TransactionConfirmationHeaderView, shouldShowChildren section: Int, index: Int) -> Bool {
        return viewModel.shouldShowChildren(for: section, index: index)
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
        delegate?.controllerDidTapEdit(self)
    }
}
