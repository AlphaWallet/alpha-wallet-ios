//
//  TokenCardSelectionViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import StatefulViewController

extension TokenCardSelectionViewController {
    enum ToolbarAction: CaseIterable {
        var isEnabled: Bool {
            return true
        }

        case clear
        case selectAll
        case sell
        case deal
        case send
        
        var title: String {
            switch self {
            case .clear:
                return R.string.localizable.semifungiblesToolbarClear()
            case .selectAll:
                return R.string.localizable.semifungiblesToolbarSelectAll()
            case .sell:
                return R.string.localizable.semifungiblesToolbarSell()
            case .deal:
                return R.string.localizable.semifungiblesToolbarDeal()
            case .send:
                return R.string.localizable.semifungiblesToolbarSend()
            }
        }
    }
}
protocol TokenCardSelectionViewControllerDelegate: class {
    func didTapSend(in viewController: TokenCardSelectionViewController, tokenObject: TokenObject, tokenHolders: [TokenHolder])
}

class TokenCardSelectionViewController: UIViewController {
    private var viewModel: TokenCardSelectionViewModel
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(SelectableTokenCardContainerTableViewCell.self)
        tableView.registerHeaderFooterView(TokenCardSelectionSectionHeaderView.self)
        tableView.dataSource = self
        tableView.estimatedRowHeight = 100
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true

        return tableView
    }()
    private var bottomConstraint: NSLayoutConstraint!
    private var specialKeyboardBottomInset: CGFloat {
        return footerBar.height
    }
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, buttonsBarHeight: specialKeyboardBottomInset)
    private let toolbar = ToolButtonsBarView()
    private let roundedBackground = RoundedBackground()
    private lazy var footerBar = ButtonsBarBackgroundView(buttonsBar: toolbar, edgeInsets: .init(top: 0, left: 0, bottom: 40, right: 0))
    private lazy var factory: TokenCardTableViewCellFactory = {
        TokenCardTableViewCellFactory()
    }()

    private var cachedCellsCardRowViews: [IndexPath: UIView & TokenCardRowViewProtocol & SelectionPositioningView] = [:]
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let server: RPCServer
    private let tokenObject: TokenObject
    weak var delegate: TokenCardSelectionViewControllerDelegate?

    init(viewModel: TokenCardSelectionViewModel, tokenObject: TokenObject, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, server: RPCServer) {
        self.tokenObject = tokenObject
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.server = server
        self.viewModel = viewModel
        searchController = UISearchController(searchResultsController: nil)
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        searchController.delegate = self
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(roundedBackground)

        roundedBackground.addSubview(tableView)
        roundedBackground.addSubview(footerBar)

        bottomConstraint = tableView.bottomAnchor.constraint(equalTo: footerBar.topAnchor)
        keyboardChecker.constraint = bottomConstraint

        NSLayoutConstraint.activate([
            footerBar.anchorsConstraint(to: view),

            tableView.topAnchor.constraint(equalTo: roundedBackground.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.safeAreaLayoutGuide.trailingAnchor),
            bottomConstraint
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure(viewModel: viewModel)

        toolbar.viewController = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardChecker.viewWillAppear()
        setupFilteringWithKeyword()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    override func viewDidLayoutSubviews() {
        configureSearchBarOnce()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func reload() {
        startLoading(animated: false)
        tableView.reloadData()
        endLoading(animated: false)
    }

    private func configure(viewModel: TokenCardSelectionViewModel) {
        self.viewModel = viewModel
        title = viewModel.navigationTitle
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor

        toolbar.configure(configuration: .buttons(type: .system, count: viewModel.actions.count))

        for (action, button) in zip(viewModel.actions, toolbar.buttons) {
            button.setTitle(action.title, for: .normal)
            button.isEnabled = viewModel.isActionEnabled(action)

            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        }
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        for (action, button) in zip(viewModel.actions, toolbar.buttons) where button == sender {
            switch action {
            case .selectAll:
                selectAllTokens()
            case .clear:
                clearAllSelections()
            case .sell, .deal:
                break
            case .send:
                delegate?.didTapSend(in: self, tokenObject: viewModel.tokenObject, tokenHolders: viewModel.tokenHolders)
            }
        }
    }

    private func clearAllSelections() {
        for indexPath in viewModel.unselectAll() {
            reconfigureCell(at: indexPath)
        }
        configure(viewModel: viewModel)
    }

    private func reconfigureCell(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? SelectableTokenCardContainerTableViewCell else { return }

        let selection = viewModel.tokenHolderSelection(indexPath: indexPath)
        cell.configure(viewModel: .init(tokenHolder: selection.tokenHolder, tokenId: selection.tokenId))
    }

    private func selectAllTokens() {
        for indexPath in viewModel.selectAllTokens() {
            reconfigureCell(at: indexPath)
        }
        configure(viewModel: viewModel)
    }
}

extension TokenCardSelectionViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfSections != .zero
    }
}

extension TokenCardSelectionViewController: UITableViewDelegate {

}

extension TokenCardSelectionViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let selection = viewModel.tokenHolderSelection(indexPath: indexPath)
        let cell: SelectableTokenCardContainerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let subview: UIView & SelectionPositioningView & TokenCardRowViewProtocol

        if let view = cachedCellsCardRowViews[indexPath] {
            subview = view
        } else {
            let view = factory.create(for: selection.tokenHolder, edgeInsets: .init(top: 5, left: 0, bottom: 5, right: 0))
            subview = view
            cachedCellsCardRowViews[indexPath] = subview
        }

        cell.prapare(with: subview)
        cell.configure(viewModel: .init(tokenHolder: selection.tokenHolder, tokenId: selection.tokenId))

        subview.configure(tokenHolder: selection.tokenHolder, tokenId: selection.tokenId, tokenView: .viewIconified, areDetailsVisible: false, width: tableView.frame.size.width, assetDefinitionStore: assetDefinitionStore)

        cell.delegate = self

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfTokens(section: section)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let tokenHolder = viewModel.selectableTokenHolder(at: section)
        let view: TokenCardSelectionSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        view.configure(viewModel: .init(tokenHolder: tokenHolder, backgroundColor: R.color.alabaster()!))
        view.delegate = self
        view.section = section

        return view
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 65
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}

extension TokenCardSelectionViewController: TokenCardSelectionSectionHeaderViewDelegate {
    func didSelectAll(in view: TokenCardSelectionSectionHeaderView) {
        guard let section = view.section else { return }

        for indexPath in viewModel.selectAllTokens(for: section) {
            guard let cell = tableView.cellForRow(at: indexPath) as? SelectableTokenCardContainerTableViewCell else { continue }

            let selection = viewModel.tokenHolderSelection(indexPath: indexPath)
            cell.configure(viewModel: .init(tokenHolder: selection.tokenHolder, tokenId: selection.tokenId))
        }

        configure(viewModel: viewModel)
    }
}

extension TokenCardSelectionViewController: SelectableTokenCardContainerTableViewCellDelegate {

    func didCloseSelection(in sender: SelectableTokenCardContainerTableViewCell, with selectedAmount: Int) {
        guard let indexPath = sender.indexPath else { return }

        let selection = viewModel.tokenHolderSelection(indexPath: indexPath)
        viewModel.selectTokens(indexPath: indexPath, selectedAmount: selectedAmount)
        sender.configure(viewModel: .init(tokenHolder: selection.tokenHolder, tokenId: selection.tokenId))

        view.endEditing(true)

        configure(viewModel: viewModel)
    }
}

extension TokenCardSelectionViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        viewModel.isSearchActive = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        viewModel.isSearchActive = false
    }
}

extension TokenCardSelectionViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.viewModel.filter = .keyword(searchController.searchBar.text)
            strongSelf.reload()
        }
    }
}

///Support searching/filtering tokens with keywords. This extension is set up so it's easier to copy and paste this functionality elsewhere
extension TokenCardSelectionViewController {
    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.dimsBackgroundDuringPresentation = false
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    private func fixTableViewBackgroundColor() {
        let v = UIView()
        v.backgroundColor = viewModel.backgroundColor
        tableView.backgroundView = v
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = viewModel.backgroundColor
    }

    private func setupFilteringWithKeyword() {
        wireUpSearchController()
        fixTableViewBackgroundColor()
        doNotDimTableViewToReuseTableForFilteringResult()
        makeSwitchToAnotherTabWorkWhileFiltering()
    }

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true

        if let placeholderLabel = searchController.searchBar.firstSubview(ofType: UILabel.self) {
            placeholderLabel.textColor = Colors.lightGray
        }
        if let textField = searchController.searchBar.firstSubview(ofType: UITextField.self) {
            textField.textColor = Colors.appText
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Colors.appText
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchController.searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
    }
}

protocol SelectAllAssetsViewDelegate: class {
    func selectAllSelected(in view: TokenCardSelectionViewController.SelectAllAssetsView)
}

extension TokenCardSelectionViewController {

    struct SelectAllAssetsViewModel {
        let text: String

        var separatorColor: UIColor = GroupedTable.Color.cellSeparator
        var backgroundColor: UIColor = GroupedTable.Color.background
        var titleTextFont = Fonts.bold(size: 15)
        var titleTextColor = R.color.dove()!
        var isSelectAllHidden: Bool = false
    }

    class SelectAllAssetsView: UIView {

        private lazy var titleLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textAlignment = .left

            return label
        }()
        
        lazy var selectAllButton: Button = {
            let button: Button = .init(size: .normal, style: .system)
            button.setTitle(R.string.localizable.semifungiblesSelectionSelectAll(), for: .normal)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }

            return button
        }()
        weak var delegate: SelectAllAssetsViewDelegate?

        init() {
            super.init(frame: .zero)

            let stackView = [titleLabel, .spacerWidth(flexible: true), selectAllButton].asStackView(axis: .horizontal)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.anchorsConstraint(to: self, edgeInsets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            ])

            translatesAutoresizingMaskIntoConstraints = false
            selectAllButton.addTarget(self, action: #selector(selectAllSelected), for: .touchUpInside)
        }

        func configure(viewModel: SelectAllAssetsViewModel) {
            titleLabel.text = viewModel.text
            titleLabel.font = viewModel.titleTextFont
            titleLabel.textColor = viewModel.titleTextColor
            backgroundColor = viewModel.backgroundColor
            selectAllButton.isHidden = viewModel.isSelectAllHidden
        }

        required init?(coder aDecoder: NSCoder) {
            return nil
        }

        @objc private func selectAllSelected(_ sender: UIButton) {
            delegate?.selectAllSelected(in: self)
        }
    }
}
