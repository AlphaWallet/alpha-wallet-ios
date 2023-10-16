// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import AlphaWalletTokenScript
import BigInt

class ActivityViewCell: UITableViewCell {
    private let background = UIView()
    private (set) var tokenScriptRendererView: TokenScriptWebView?
    private var isFirstLoad = true
    private var viewModel: ActivityCellViewModel? {
        didSet {
            guard let tokenScriptRendererView = tokenScriptRendererView else { return }

            if let oldValue = oldValue {
                if oldValue.activity.id == viewModel?.activity.id {
                    //no-op
                } else {
                    isFirstLoad = true
                    if let server = viewModel?.activity.server {
                        //TODO make sure updating the server like this works
                        tokenScriptRendererView.setServer(server, serverWithInjectableRpcUrl: server)
                    }
                }
            } else {
                isFirstLoad = true
                if let server = viewModel?.activity.server {
                    //TODO make sure updating the server like this works
                    tokenScriptRendererView.setServer(server, serverWithInjectableRpcUrl: server)
                }
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            background.anchorsConstraint(to: contentView),

            contentView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    func setupTokenScriptRendererView(_ tokenScriptRendererView: TokenScriptWebView) {
        tokenScriptRendererView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(tokenScriptRendererView)

        NSLayoutConstraint.activate([
            tokenScriptRendererView.anchorsConstraint(to: background),
        ])

        self.tokenScriptRendererView = tokenScriptRendererView
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ActivityCellViewModel) {
        guard let tokenScriptRendererView = tokenScriptRendererView else { return }
        self.viewModel = viewModel

        selectionStyle = .none
        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = viewModel.contentsCornerRadius

        backgroundColor = viewModel.backgroundColor

        tokenScriptRendererView.loadHtml(viewModel.activity.itemViewHtml.html, urlFragment: viewModel.activity.itemViewHtml.urlFragment)

        let tokenAttributes = viewModel.activity.values.token
        let cardAttributes = viewModel.activity.values.card
        tokenScriptRendererView.update(withId: .init(viewModel.activity.id), resolvedTokenAttributeNameValues: tokenAttributes, resolvedCardAttributeNameValues: cardAttributes, isFirstUpdate: isFirstLoad)
        isFirstLoad = false
    }
}
