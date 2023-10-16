//
//  NFTPreviewView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.05.2022.
//

import UIKit
import AlphaWalletFoundation
import Combine

typealias NFTPreviewViewRepresentable = UIView & NFTPreviewConfigurable & ViewRoundingSupportable & ContentBackgroundSupportable & ViewLoadingSupportable

enum NFTPreviewViewType {
    case tokenCardView
    case imageView

    enum Params {
        case image(iconImage: TokenImagePublisher)
        case tokenScriptWebView(tokenHolder: TokenHolder, tokenId: TokenId)
    }
}

protocol NFTPreviewConfigurable {
    func configure(params: NFTPreviewViewType.Params)
}

final class NFTPreviewView: NFTPreviewViewRepresentable {
    private var previewView: NFTPreviewViewRepresentable

    var rounding: ViewRounding = .none {
        didSet { previewView.rounding = rounding }
    }
    var placeholderRounding: ViewRounding = .none {
        didSet { previewView.placeholderRounding = placeholderRounding }
    }

    override var contentMode: UIView.ContentMode {
        didSet { previewView.contentMode = contentMode }
    }

    var contentBackgroundColor: UIColor? {
        get { return previewView.contentBackgroundColor }
        set { previewView.contentBackgroundColor = newValue }
    }

    var loading: ViewLoading {
        get { return previewView.loading }
        set { previewView.loading = newValue }
    }

    init(type: NFTPreviewViewType,
         session: WalletSession,
         assetDefinitionStore: AssetDefinitionStore,
         edgeInsets: UIEdgeInsets = .zero,
         playButtonPositioning: AVPlayerView.PlayButtonPositioning) {

        switch type {
        case .imageView:
            previewView = NFTPreviewView.generateTokenImageView(playButtonPositioning: playButtonPositioning)
        case .tokenCardView:
            previewView = NFTPreviewView.generateTokenCardView(session: session, assetDefinitionStore: assetDefinitionStore)
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

    private static func generateTokenCardView(session: WalletSession,
                                              assetDefinitionStore: AssetDefinitionStore) -> TokenCardWebView {
        let tokeCardWebView = TokenCardWebView(
            server: session.server,
            //TODO should this be viewIconified instead? But it has to be `.view` for Smart Cats
            tokenView: .view,
            assetDefinitionStore: assetDefinitionStore,
            wallet: session.account)

        return tokeCardWebView
    }

    private static func generateTokenImageView(playButtonPositioning: AVPlayerView.PlayButtonPositioning) -> TokenImageView {
        let imageView = TokenImageView(playButtonPositioning: playButtonPositioning)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        imageView.rounding = .none
        imageView.isChainOverlayHidden = true
        imageView.contentMode = .scaleAspectFit

        return imageView
    }
}

extension TokenImageView: NFTPreviewConfigurable, ContentBackgroundSupportable {
    var contentBackgroundColor: UIColor? {
        get { return imageView.contentBackgroundColor }
        set { imageView.contentBackgroundColor = newValue }
    }

    func configure(params: NFTPreviewViewType.Params) {
        guard case .image(let iconImage) = params else { set(imageSource: .just(nil)); return; }
        set(imageSource: iconImage)
    }
}

extension TokenCardWebView: NFTPreviewConfigurable, ContentBackgroundSupportable {
    var contentBackgroundColor: UIColor? {
        get { return backgroundColor }
        set { backgroundColor = newValue }
    }

    func configure(params: NFTPreviewViewType.Params) {
        guard case .tokenScriptWebView(let tokenHolder, let tokenId) = params else { return }
        configure(tokenHolder: tokenHolder, tokenId: tokenId)
    }
}
