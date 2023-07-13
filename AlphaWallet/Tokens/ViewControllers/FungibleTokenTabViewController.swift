//
//  FungibleTokenTabViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.11.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

protocol FungibleTokenTabViewControllerDelegate: AnyObject, CanOpenURL2 {
    func didClose(in viewController: FungibleTokenTabViewController)
}

class FungibleTokenTabViewController: TopTabBarViewController {
    private let viewModel: FungibleTokenTabViewModel
    private var cancelable = Set<AnyCancellable>()
    private let willAppear = PassthroughSubject<Void, Never>()

    weak var delegate: FungibleTokenTabViewControllerDelegate?

    init(viewModel: FungibleTokenTabViewModel) {
        self.viewModel = viewModel
        super.init(titles: viewModel.tabBarItems.map { $0.description })
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: viewModel.tokenScriptFileStatusHandler)
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
        willAppear.send(())
    }

    private func bind(viewModel: FungibleTokenTabViewModel) {
        let input = FungibleTokenTabViewModelInput(willAppear: willAppear.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)
        output.viewState
            .map { $0.title }
            .assign(to: \.title, on: navigationItem, ownership: .weak)
            .store(in: &cancelable)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateNavigationRightBarButtons(tokenScriptFileStatusHandler xmlHandler: XMLHandler) {
        if Features.current.isAvailable(.isTokenScriptSignatureStatusEnabled) {
            let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
            if tokenScriptStatusPromise.isPending {
                let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
                navigationItem.rightBarButtonItem = label

                tokenScriptStatusPromise.done { [weak self] _ in
                    self?.updateNavigationRightBarButtons(tokenScriptFileStatusHandler: xmlHandler)
                }.cauterize()
            }

            if let server = xmlHandler.server, let status = tokenScriptStatusPromise.value, server.matches(server: viewModel.session.server) {
                switch status {
                case .type0NoTokenScript:
                    navigationItem.rightBarButtonItem = nil
                case .type1GoodTokenScriptSignatureGoodOrOptional, .type2BadTokenScript:
                    let button = createTokenScriptFileStatusButton(withStatus: status, urlOpener: self)
                    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
                }
            } else {
                navigationItem.rightBarButtonItem = nil
            }
        } else {
            //no-op
        }
    }
}

extension FungibleTokenTabViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension FungibleTokenTabViewController: CanOpenURL2 {
    func open(url: URL) {
        delegate?.open(url: url)
    }
}
