//
//  TokenCardWebView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2022.
//

import Foundation
import UIKit
import AlphaWalletFoundation

class TokenCardWebView: UIView, TokenCardRowViewConfigurable, ViewRoundingSupportable, ViewLoadingCancelable {
    private let analytics: AnalyticsLogger
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore
    private var lastTokenHolder: TokenHolder?
    private var tokenView: TokenView
    private let keystore: Keystore
    private let wallet: Wallet
    private lazy var tokenScriptRendererView: TokenInstanceWebView = {
        let webView = TokenInstanceWebView(analytics: analytics, server: server, wallet: wallet, assetDefinitionStore: assetDefinitionStore, keystore: keystore)
        webView.delegate = self
        return webView
    }()

    var rounding: ViewRounding = .none
    var additionalHeightToCompensateForAutoLayout: CGFloat { return 0 }
    var isStandalone: Bool {
        get { return tokenScriptRendererView.isStandalone }
        set { tokenScriptRendererView.isStandalone = newValue }
    }

    init(analytics: AnalyticsLogger, server: RPCServer, tokenView: TokenView, assetDefinitionStore: AssetDefinitionStore, keystore: Keystore, wallet: Wallet) {
        self.keystore = keystore
        self.analytics = analytics
        self.server = server
        self.tokenView = tokenView
        self.assetDefinitionStore = assetDefinitionStore
        self.wallet = wallet

        super.init(frame: .zero)

        addSubview(tokenScriptRendererView)
        NSLayoutConstraint.activate([
            tokenScriptRendererView.anchorsConstraint(to: self)
        ])
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId) {
        lastTokenHolder = tokenHolder
        configure(viewModel: TokenCardWebViewModel(tokenHolder: tokenHolder, tokenId: tokenId, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
    }

    private func configure(viewModel: TokenCardWebViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
        if viewModel.hasTokenScriptHtml {
            tokenScriptRendererView.isHidden = false
            let (html: html, hash: hash) = viewModel.tokenScriptHtml
            tokenScriptRendererView.loadHtml(html, hash: hash)
            tokenScriptRendererView.update(withTokenHolder: viewModel.tokenHolder, isFungible: false)
        } else {
            tokenScriptRendererView.isHidden = true
        }
    }

    func cancel() {
        tokenScriptRendererView.stopLoading()
    }
}

extension TokenCardWebView: TokenInstanceWebViewDelegate {
    func navigationControllerFor(tokenInstanceWebView: TokenInstanceWebView) -> UINavigationController? {
        return nil
    }

    func shouldClose(tokenInstanceWebView: TokenInstanceWebView) {
        //no-op
    }

    func reinject(tokenInstanceWebView: TokenInstanceWebView) {
        //Refresh if view, but not item-view
        if isStandalone {
            guard let lastTokenHolder = lastTokenHolder else { return }
            configure(viewModel: TokenCardWebViewModel(tokenHolder: lastTokenHolder, tokenId: lastTokenHolder.tokenId, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
        } else {
            //no-op for item-views
        }
    }
}
