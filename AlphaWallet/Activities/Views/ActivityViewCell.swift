// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt

class ActivityViewCell: UITableViewCell {
    private let background = UIView()
    lazy private var tokenScriptRendererView: TokenInstanceWebView = {
        //TODO pass in keystore or wallet address instead. Have to think about initialization of cells
        let wallet = EtherKeystore.currentWallet
        //TODO server value doesn't matter since we will change it later. But we should improve this
        let webView = TokenInstanceWebView(server: .main, wallet: wallet, assetDefinitionStore: AssetDefinitionStore.instance)
        //TODO needed? Seems like scary, performance-wise
        //webView.delegate = self
        return webView
    }()
    private var isFirstLoad = true
    private var viewModel: ActivityCellViewModel? {
        didSet {
            if let oldValue = oldValue {
                if oldValue.activity.id == viewModel?.activity.id {
                    //no-op
                } else {
                    isFirstLoad = true
                    if let server = viewModel?.activity.server {
                        //TODO make sure updating the server like this works
                        tokenScriptRendererView.server = server
                    }
                }
            } else {
                isFirstLoad = true
                if let server = viewModel?.activity.server {
                    //TODO make sure updating the server like this works
                    tokenScriptRendererView.server = server
                }
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        tokenScriptRendererView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(tokenScriptRendererView)

        NSLayoutConstraint.activate([
            tokenScriptRendererView.anchorsConstraint(to: background),

            background.anchorsConstraint(to: contentView),

            contentView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ActivityCellViewModel) {
        self.viewModel = viewModel

        selectionStyle = .none
        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = viewModel.contentsCornerRadius

        backgroundColor = viewModel.backgroundColor

        let (html: html, hash: hash) = viewModel.activity.itemViewHtml
        tokenScriptRendererView.loadHtml(html, hash: hash)

        let tokenAttributes = viewModel.activity.values.token
        let cardAttributes = viewModel.activity.values.card
        tokenScriptRendererView.update(withId: .init(viewModel.activity.id), resolvedTokenAttributeNameValues: tokenAttributes, resolvedCardAttributeNameValues: cardAttributes, isFirstUpdate: isFirstLoad)
        isFirstLoad = false
    }
}
