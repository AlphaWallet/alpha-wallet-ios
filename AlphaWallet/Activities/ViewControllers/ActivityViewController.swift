// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol ActivityViewControllerDelegate: class {
    func reinject(viewController: ActivityViewController)
}

class ActivityViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private let assetDefinitionStore: AssetDefinitionStore
    lazy private var tokenScriptRendererView: TokenInstanceWebView = {
        //TODO pass in keystore or wallet address instead
        let walletAddress = EtherKeystore.current!.address
        let webView = TokenInstanceWebView(server: server, walletAddress: walletAddress, assetDefinitionStore: assetDefinitionStore)
        webView.isWebViewInteractionEnabled = true
        webView.delegate = self
        webView.isStandalone = true
        webView.isAction = true
        return webView
    }()
    private var isFirstLoad = true

    private var server: RPCServer {
        viewModel.activity.tokenObject.server
    }

    var viewModel: ActivityViewModel

    weak var delegate: ActivityViewControllerDelegate?

    init(assetDefinitionStore: AssetDefinitionStore, viewModel: ActivityViewModel) {
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tokenScriptRendererView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(tokenScriptRendererView)

        NSLayoutConstraint.activate([
            tokenScriptRendererView.anchorsConstraint(to: roundedBackground),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ActivityViewModel) {
        self.viewModel = viewModel

        let (html: html, hash: hash) = viewModel.activity.viewHtml
        tokenScriptRendererView.loadHtml(html, hash: hash)

        let tokenAttributes = viewModel.activity.values.token
        let cardAttributes = viewModel.activity.values.card
        tokenScriptRendererView.update(withId: .init(viewModel.activity.id), resolvedTokenAttributeNameValues: tokenAttributes, resolvedCardAttributeNameValues: cardAttributes, isFirstUpdate: isFirstLoad)
        isFirstLoad = false
    }

    func isForActivity(_ activity: Activity) -> Bool {
        viewModel.activity.id == activity.id
    }
}

extension ActivityViewController: TokenInstanceWebViewDelegate {
    //TODO not good. But quick and dirty to ship
    func navigationControllerFor(tokenInstanceWebView: TokenInstanceWebView) -> UINavigationController? {
        navigationController
    }

    func shouldClose(tokenInstanceWebView: TokenInstanceWebView) {
        //no-op
    }

    func heightChangedFor(tokenInstanceWebView: TokenInstanceWebView) {
        //no-op. Auto layout handles it
    }

    func reinject(tokenInstanceWebView: TokenInstanceWebView) {
        delegate?.reinject(viewController: self)
    }
}
