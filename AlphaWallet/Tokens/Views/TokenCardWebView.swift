//
//  TokenCardWebView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2022.
//

import Combine
import Foundation
import UIKit
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletTokenScript

class TokenCardWebView: UIView, TokenCardRowViewConfigurable, ViewRoundingSupportable, ViewLoadingSupportable {
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore
    private var lastTokenHolder: TokenHolder?
    private var tokenView: TokenView
    private let wallet: Wallet
    private lazy var tokenScriptRendererView: TokenScriptWebView = {
        let webView = TokenScriptWebView(server: server, serverWithInjectableRpcUrl: server, wallet: wallet.type, assetDefinitionStore: assetDefinitionStore)
        webView.delegate = self
        webView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        return webView
    }()

    var rounding: ViewRounding = .none
    var loading: ViewLoading = .disabled
    var placeholderRounding: ViewRounding = .none

    var isStandalone: Bool {
        get { return tokenScriptRendererView.isStandalone }
        set { tokenScriptRendererView.isStandalone = newValue }
    }

    init(server: RPCServer,
         tokenView: TokenView,
         assetDefinitionStore: AssetDefinitionStore,
         wallet: Wallet) {

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
        configure(viewModel: TokenCardWebViewModel(
            tokenHolder: tokenHolder,
            tokenId: tokenId,
            tokenView: tokenView,
            assetDefinitionStore: assetDefinitionStore))
    }

    private func configure(viewModel: TokenCardWebViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
        if viewModel.hasTokenScriptHtml {
            tokenScriptRendererView.isHidden = false
            tokenScriptRendererView.loadHtml(viewModel.tokenScriptHtml.html, urlFragment: viewModel.tokenScriptHtml.urlFragment)
            tokenScriptRendererView.update(withTokenHolder: viewModel.tokenHolder, isFungible: false)
        } else {
            tokenScriptRendererView.isHidden = true
        }
    }

    func cancel() {
        tokenScriptRendererView.stopLoading()
    }
}

extension TokenCardWebView: TokenScriptWebViewDelegate {
    func requestSignMessage(message: SignMessageType, server: RPCServer, account: AlphaWallet.Address, inTokenScriptWebView tokenScriptWebView: TokenScriptWebView) -> AnyPublisher<Data, PromiseError> {
        return .empty()
    }

    func shouldClose(tokenScriptWebView: TokenScriptWebView) {
        //no-op
    }

    func reinject(tokenScriptWebView: TokenScriptWebView) {
        //Refresh if view, but not item-view
        if isStandalone {
            guard let lastTokenHolder = lastTokenHolder else { return }

            configure(viewModel: TokenCardWebViewModel(
                tokenHolder: lastTokenHolder,
                tokenId: lastTokenHolder.tokenId,
                tokenView: tokenView,
                assetDefinitionStore: assetDefinitionStore))
        } else {
            //no-op for item-views
        }
    }
}
