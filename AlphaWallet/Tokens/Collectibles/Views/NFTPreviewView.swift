//
//  NFTPreviewView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.05.2022.
//

import UIKit
import AlphaWalletFoundation

class NFTPreviewView: UIView, ConfigurableNFTPreviewView, ViewRoundingSupportable, ContentBackgroundSupportable, ViewLoadingCancelable {
    private var previewView: UIView & ConfigurableNFTPreviewView & ViewRoundingSupportable & ContentBackgroundSupportable & ViewLoadingCancelable

    var rounding: ViewRounding = .none {
        didSet { previewView.rounding = rounding }
    }
    
    override var contentMode: UIView.ContentMode {
        didSet { previewView.contentMode = contentMode }
    }

    var contentBackgroundColor: UIColor? {
        get { return previewView.contentBackgroundColor }
        set { previewView.contentBackgroundColor = newValue }
    }

    init(type: NFTPreviewViewType, keystore: Keystore, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, edgeInsets: UIEdgeInsets = .zero) {
        switch type {
        case .imageView:
            previewView = NFTPreviewView.generateTokenImageView()
        case .tokenCardView:
            previewView = NFTPreviewView.generateTokenCardView(keystore: keystore, session: session, assetDefinitionStore: assetDefinitionStore, analytics: analytics)
        }
        super.init(frame: .zero)

        addSubview(previewView)

        NSLayoutConstraint.activate([
            previewView.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(params: NFTPreviewViewType.Params) {
        previewView.configure(params: params)
    }

    func cancel() {
        previewView.cancel()
    }

    private static func generateTokenCardView(keystore: Keystore, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger) -> TokenCardWebView {
        let tokeCardWebView = TokenCardWebView(analytics: analytics, server: session.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, keystore: keystore, wallet: session.account)
        return tokeCardWebView
    }

    private static func generateTokenImageView() -> TokenImageView {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        imageView.rounding = .none
        imageView.isChainOverlayHidden = true
        imageView.contentMode = .scaleAspectFit

        return imageView
    }
}

extension TokenImageView: ConfigurableNFTPreviewView, ContentBackgroundSupportable {
    var contentBackgroundColor: UIColor? {
        get { return imageView.contentBackgroundColor }
        set { imageView.contentBackgroundColor = newValue }
    }

    func configure(params: NFTPreviewViewType.Params) {
        guard case .image(let iconImage) = params else { subscribable = .none; return; }
        subscribable = iconImage
    }
}

extension TokenCardWebView: ConfigurableNFTPreviewView, ContentBackgroundSupportable {
    var contentBackgroundColor: UIColor? {
        get { return backgroundColor }
        set { backgroundColor = newValue }
    }

    func configure(params: NFTPreviewViewType.Params) {
        guard case .tokenScriptWebView(let tokenHolder, let tokenId) = params else { return }
        configure(tokenHolder: tokenHolder, tokenId: tokenId)
    }
}
