//
//  AssetsPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit

protocol AssetsPageViewDelegate: class {
    func assetsPageView(_ view: AssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder)
}

class AssetsPageView: UIView, PageViewType {
    var title: String {
        viewModel.navigationTitle
    }
    private var viewModel: AssetsPageViewModel
    weak var delegate: AssetsPageViewDelegate?

    var rightBarButtonItem: UIBarButtonItem?

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(TokenCardContainerTableViewCell.self)
        tableView.isEditing = false
        tableView.estimatedRowHeight = 100
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = .zero
        tableView.contentInset = .zero
        tableView.contentOffset = .zero
        tableView.tableHeaderView = UIView()
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()

    private let refreshControl = UIRefreshControl()
    private let tokenObject: TokenObject
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let server: RPCServer

    init(tokenObject: TokenObject, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, server: RPCServer, viewModel: AssetsPageViewModel) {
        self.viewModel = viewModel
        self.tokenObject = tokenObject
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.server = server
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Colors.appBackground

        addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
        fixTableViewBackgroundColor()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: AssetsPageViewModel) {
        self.viewModel = viewModel
        tableView.reloadData()
    }

    private func fixTableViewBackgroundColor() {
        let v = UIView()
        v.backgroundColor = viewModel.backgroundColor
        tableView.backgroundView = v
    }

    private lazy var factory: TokenCardTableViewCellFactory = {
        TokenCardTableViewCellFactory()
    }()

    private var cachedTokenCardRowViews: [IndexPath: TokenCardRowViewProtocol & UIView] = [:]
}

extension AssetsPageView: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfItems(section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let tokenHolder = viewModel.item(atIndexPath: indexPath) else { return UITableViewCell() }
        let cell: TokenCardContainerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.containerEdgeInsets = .zero

        let subview: UIView & TokenCardRowViewProtocol
        if let value = cachedTokenCardRowViews[indexPath] {
            subview = value
        } else {
            subview = factory.create(for: tokenHolder)

            cachedTokenCardRowViews[indexPath] = subview
        }

        cell.configure(subview: subview)
        configure(container: cell, tokenHolder: tokenHolder)

        return cell
    }

    private func configure(container: TokenCardContainerTableViewCell, tokenHolder: TokenHolder) {
        container.delegate = self

        container.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width, tokenView: .viewIconified), tokenId: tokenHolder.tokenId, assetDefinitionStore: assetDefinitionStore)
    }
}

extension AssetsPageView: BaseTokenCardTableViewCellDelegate {
    func didTapURL(url: URL) {

    }
}

extension AssetsPageView: UITableViewDelegate {

    //Hide the header
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let tokenHolder = viewModel.item(atIndexPath: indexPath) else { return }

        delegate?.assetsPageView(self, didSelectTokenHolder: tokenHolder)
    }
} 
