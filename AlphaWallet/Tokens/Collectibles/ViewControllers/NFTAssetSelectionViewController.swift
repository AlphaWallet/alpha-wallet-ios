//
//  NFTAssetSelectionViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import StatefulViewController
import AlphaWalletFoundation
import Combine

protocol NFTAssetSelectionViewControllerDelegate: AnyObject {
    func didTapSend(in viewController: NFTAssetSelectionViewController, token: Token, tokenHolders: [TokenHolder])
}

class NFTAssetSelectionViewController: UIViewController {
    private let viewModel: NFTAssetSelectionViewModel
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        return searchController
    }()

    private var isSearchBarConfigured = false
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(SelectableAssetTableViewCell.self)
        tableView.registerHeaderFooterView(NFTAssetSelectionSectionHeaderView.self)
        tableView.estimatedRowHeight = 100
        tableView.delegate = self
        tableView.separatorInset = .zero
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true

        return tableView
    }()
    private lazy var bottomConstraint: NSLayoutConstraint = {
        return tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }()
    private lazy var keyboardChecker: KeyboardChecker = {
        let keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
        keyboardChecker.constraints = [bottomConstraint]
        return keyboardChecker
    }()
    private let toolbar = ToolButtonsBarView()

    private lazy var footerBar = ButtonsBarBackgroundView(buttonsBar: toolbar)
    private let tokenCardViewFactory: TokenCardViewFactory
    private var cancellable = Set<AnyCancellable>()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let assetsSelection = PassthroughSubject<NFTAssetSelectionViewModel.AssetsSelection, Never>()
    private let selectedAsset = PassthroughSubject<NFTAssetSelectionViewModel.SelectedAsset, Never>()
    private let toolbarAction = PassthroughSubject<NFTAssetSelectionViewModel.ToolbarAction, Never>()
    private let assetsFilter = PassthroughSubject<NFTAssetSelectionViewModel.AssetFilter, Never>()
    private lazy var dataSource = makeDataSource()
    private weak var selectionView: EnterAssetAmountView?

    weak var delegate: NFTAssetSelectionViewControllerDelegate?

    init(viewModel: NFTAssetSelectionViewModel, tokenCardViewFactory: TokenCardViewFactory) {
        self.tokenCardViewFactory = tokenCardViewFactory
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        view.addSubview(footerBar)
        
        NSLayoutConstraint.activate([
            footerBar.anchorsConstraint(to: view),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            bottomConstraint
        ])

        toolbar.viewController = self

        emptyView = EmptyView.nftAssetsEmptyView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Configuration.Color.Semantic.tableViewBackground
        tableView.backgroundColor = Configuration.Color.Semantic.tableViewBackground

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardChecker.viewWillAppear()
        setupFilteringWithKeyword()
        willAppear.send(())
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

    private func bind(viewModel: NFTAssetSelectionViewModel) {
        keyboardChecker.publisher
            .map { $0.isVisible }
            .prepend(false)
            .map { [footerBar] in $0 ? UIEdgeInsets.zero : UIEdgeInsets(top: 0, left: 0, bottom: footerBar.height, right: 0) }
            .removeDuplicates()
            .sink { [tableView] in
                tableView.contentInset = $0
                tableView.scrollIndicatorInsets = $0
            }.store(in: &cancellable)

        let input = NFTAssetSelectionViewModelInput(
            assetsFilter: assetsFilter.eraseToAnyPublisher(),
            toolbarAction: toolbarAction.eraseToAnyPublisher(),
            assetsSelection: assetsSelection.eraseToAnyPublisher(),
            selectedAsset: selectedAsset.eraseToAnyPublisher(),
            willAppear: willAppear.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.manualAssetsAmountSelection
            .sink { [weak self] in self?.showAssetSelection(indexPath: $0.indexPath, available: $0.available, selected: $0.selected) }
            .store(in: &cancellable)

        output.viewState
            .sink { [weak self] viewState in
                self?.navigationItem.title = viewState.title
                self?.buildToolbar(actions: viewState.actions)

                self?.dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
                self?.endLoading()
            }.store(in: &cancellable)

        output.sendSelected
            .sink { [weak self] data in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didTapSend(in: strongSelf, token: data.token, tokenHolders: data.tokenHolders)
            }.store(in: &cancellable)
    }
    
    private func showAssetSelection(indexPath: IndexPath, available: Int, selected: Int) {
        self.selectionView?.removeFromSuperview()

        let viewModel = EnterAssetAmountViewModel(available: available, selected: selected)
        let selectionView = EnterAssetAmountView(viewModel: viewModel)
        self.selectionView = selectionView

        viewModel.selected
            .map { NFTAssetSelectionViewModel.SelectedAsset(selected: $0, indexPath: indexPath) }
            .multicast(subject: self.selectedAsset)
            .connect()
            .store(in: &selectionView.cancellable)

        viewModel.close
            .sink { [weak self] _ in self?.selectionView?.removeFromSuperview() }
            .store(in: &selectionView.cancellable)

        view.addSubview(selectionView)
        viewModel.activateSelection()
    }

    private func buildToolbar(actions: [NFTAssetSelectionViewModel.ToolbarActionViewModel]) {
        toolbar.cancellable.cancellAll()
        toolbar.configure(configuration: .buttons(type: .system, count: actions.count))

        for (action, button) in zip(actions, toolbar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.isEnabled = action.isEnabled

            button.publisher(forEvent: .touchUpInside)
                .map { _ in action.type }
                .multicast(subject: toolbarAction)
                .connect()
                .store(in: &toolbar.cancellable)
        }
    }
}

extension NFTAssetSelectionViewController {
    private func makeDataSource() -> NFTAssetSelectionViewModel.DataSource {
        NFTAssetSelectionViewModel.DataSource(tableView: tableView) { [weak self] tableView, indexPath, viewModel -> SelectableAssetTableViewCell in
            guard let strongSelf = self else { return SelectableAssetTableViewCell() }

            let cell: SelectableAssetTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            let subview = strongSelf.tokenCardViewFactory.createTokenCardView(
                for: viewModel.tokenHolder,
                layout: .list,
                listEdgeInsets: .init(top: 5, left: 0, bottom: 5, right: 0))

            cell.prapare(with: subview)
            cell.configure(viewModel: .init(
                selected: viewModel.selected,
                available: viewModel.available,
                isSelected: viewModel.isSelected,
                name: viewModel.name))

            subview.configure(tokenHolder: viewModel.tokenHolder, tokenId: viewModel.tokenId)
            //NOTE: tweak views background color
            subview.backgroundColor = .clear

            return cell
        }
    }
}

extension NFTAssetSelectionViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension NFTAssetSelectionViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        assetsSelection.send(.item(indexPath: indexPath))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionViewModel = dataSource.snapshot().sectionIdentifiers[section]

        let view: NFTAssetSelectionSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        view.cancellable.cancellAll()
        view.configure(viewModel: .init(name: sectionViewModel.name, backgroundColor: Configuration.Color.Semantic.tableViewAccessoryBackground))
        view.publisher
            .map { _ in NFTAssetSelectionViewModel.AssetsSelection.all(section: section) }
            .multicast(subject: assetsSelection)
            .connect()
            .store(in: &view.cancellable)

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

extension NFTAssetSelectionViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async { [weak self] in
            self?.assetsFilter.send(.keyword(searchController.searchBar.text))
        }
    }
}

///Support searching/filtering tokens with keywords. This extension is set up so it's easier to copy and paste this functionality elsewhere
extension NFTAssetSelectionViewController {
    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    private func fixTableViewBackgroundColor() {
        let v = UIView()
        v.backgroundColor = view.backgroundColor
        tableView.backgroundView = v
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = view.backgroundColor
    }

    private func setupFilteringWithKeyword() {
        wireUpSearchController()
        fixTableViewBackgroundColor()
        makeSwitchToAnotherTabWorkWhileFiltering()
    }

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true

        if let placeholderLabel = searchController.searchBar.firstSubview(ofType: UILabel.self) {
            placeholderLabel.textColor = Configuration.Color.Semantic.searchbarPlaceholder
        }
        if let textField = searchController.searchBar.firstSubview(ofType: UITextField.self) {
            textField.textColor = Configuration.Color.Semantic.defaultForegroundText
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Configuration.Color.Semantic.defaultIcon
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchController.searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
    }
}

extension NFTAssetSelectionViewController {

    struct SelectAllAssetsViewModel {
        let text: String

        var separatorColor: UIColor = Configuration.Color.Semantic.tableViewSeparator
        var backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground
        var titleTextFont = Fonts.bold(size: 15)
        var titleTextColor = Configuration.Color.Semantic.defaultSubtitleText
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

        init() {
            super.init(frame: .zero)

            let stackView = [titleLabel, .spacerWidth(flexible: true), selectAllButton].asStackView(axis: .horizontal)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.anchorsConstraint(to: self, edgeInsets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            ])

            translatesAutoresizingMaskIntoConstraints = false
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
    }
}
