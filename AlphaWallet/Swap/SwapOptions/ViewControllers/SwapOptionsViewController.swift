//
//  SwapOptionsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine

protocol SwapOptionsViewControllerDelegate: AnyObject {
    func didClose(in controller: SwapOptionsViewController)
}

class SwapOptionsViewController: UIViewController {
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    private var viewModel: SwapOptionsViewModel

    private lazy var slippageView: SlippageView = {
        return SlippageView(viewModel: viewModel.slippageViewModel)
    }()

    private lazy var slippageHeaderView: SwapOptionsHeaderView = {
        let view = SwapOptionsHeaderView(viewModel: .init(title: "SLIPPAGE TOLERANCE"))
        return view
    }()

    private lazy var networkHeaderView: SwapOptionsHeaderView = {
        let view = SwapOptionsHeaderView(viewModel: .init(title: "Network"))
        return view
    }()

    private lazy var checker = KeyboardChecker(self, resetHeightDefaultValue: 0)
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
    private var cancelable = Set<AnyCancellable>()
    private var walletSessionViews: [SelectNetworkView] = []

    weak var delegate: SwapOptionsViewControllerDelegate?
    var scrollView: UIScrollView {
        containerView.scrollView
    }
    
    init(viewModel: SwapOptionsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(containerView)

        let bottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bottomConstraint
        ])

        checker.constraints = [bottomConstraint]
        generateSubviews(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checker.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        checker.viewWillDisappear()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        headerView.configure(viewModel: .init(title: viewModel.navigationTitle))
        bind(viewModel: viewModel)
        headerView.closeButton.addTarget(self, action: #selector(closeDidSelect), for: .touchUpInside)

        containerView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewDidTap))
        containerView.addGestureRecognizer(tap)
    } 

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func viewDidTap(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    @objc private func closeDidSelect(_ sender: UIButton) {
        delegate?.didClose(in: self)
    }

    private func bind(viewModel: SwapOptionsViewModel) {
        let output = viewModel.transform(input: .init())
        output.sessions
            .sink { [weak self] viewModels in
                for index in viewModels.indices {
                    guard let view = self?.walletSessionViews[safe: index] else { continue }
                    view.configure(viewModel: viewModels[index])
                }
            }.store(in: &cancelable)

        //TODO: need to resolve error displaying, uncommenting this string causes displaying an error when screen in loading for first time
        // and for unavailable networks it shows error
        //output.errorString
        //    .receive(on: RunLoop.main)
        //    .sink { [weak self] error in
        //        self?.displayError(message: error)
        //    }.store(in: &cancelable)
    }

    private func generateSubviews(viewModel: SwapOptionsViewModel) {
        containerView.stackView.removeAllArrangedSubviews()
        var walletSessionViews: [UIView] = []

        for each in viewModel.sessions {
            let view = SelectNetworkView(edgeInsets: .init(top: 10, left: 15, bottom: 10, right: 15))
            UITapGestureRecognizer(addToView: view) {
                viewModel.set(selectedServer: each.server)
            }
            self.walletSessionViews += [view]
            walletSessionViews += [
                .spacer(height: 1, backgroundColor: R.color.mercury()!),
                view
            ]
        }

        walletSessionViews += [
            .spacer(height: 1, backgroundColor: R.color.mercury()!)
        ]

        let subviews: [UIView] = [
            headerView,
            .spacer(height: 30),
            slippageHeaderView.adjusted(),
            .spacer(height: 10),
            slippageView.adjusted(),
            .spacer(height: 30),
            networkHeaderView.adjusted(),
            .spacer(height: 10),
        ] + walletSessionViews

        containerView.stackView.addArrangedSubviews(subviews)
    }
}

extension UITextField {

    var textPublisher: AnyPublisher<String?, Never> {
        return Publishers
            .Merge(publisher(forEvent: .editingDidBegin), publisher(forEvent: .editingChanged))
            .map { _ -> String? in self.text }
            .eraseToAnyPublisher()
    }
}

extension UIView {
    func adjusted(adjusment: CGFloat = 15) -> UIView {
        return [.spacerWidth(adjusment), self, .spacerWidth(adjusment)].asStackView()
    }
}
