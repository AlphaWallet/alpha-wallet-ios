//
//  NFTPreviewView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.05.2022.
//

import UIKit

class NFTPreviewView: UIView, ConfigurableNFTPreviewView, ViewRoundingSupportable {

    private var previewView: UIView & ConfigurableNFTPreviewView & ViewRoundingSupportable
    var rounding: ViewRounding = .none { didSet { previewView.rounding = rounding } }

    init(type: NFTPreviewViewType, keystore: Keystore, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, edgeInsets: UIEdgeInsets = .zero) {
        switch type {
        case .imageView:
            previewView = NFTPreviewView.generateTokenImageView()
        case .tokenCardView:
            previewView = NFTPreviewView.generateTokenCardView(keystore: keystore, session: session, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator)
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

    private static func generateTokenCardView(keystore: Keystore, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator) -> TokenCardWebView {
        let tokeCardWebView = TokenCardWebView(analyticsCoordinator: analyticsCoordinator, server: session.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, keystore: keystore, wallet: session.account)
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

extension TokenImageView: ConfigurableNFTPreviewView {
    func configure(params: NFTPreviewViewType.Params) {
        guard case .image(let iconImage) = params else { subscribable = .none; return; }
        subscribable = iconImage
    }
}

extension TokenCardWebView: ConfigurableNFTPreviewView {
    func configure(params: NFTPreviewViewType.Params) {
        guard case .some(let tokenHolder, let tokenId, let tokenView, let assetDefinitionStore) = params else { return }
        configure(tokenHolder: tokenHolder, tokenId: tokenId, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore)
    }
}

