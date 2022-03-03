//
//  AssetsPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import StatefulViewController 

extension NSNotification.Name {
    static let invalidateLayout = NSNotification.Name(rawValue: "InvalidateLayout")
}

protocol AssetsPageViewDelegate: class {
    func assetsPageView(_ view: AssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder)
}
typealias TokenHoldersDataSource = UICollectionViewDiffableDataSource<AssetsPageViewModel.AssetsSection, TokenHolder>

class AssetsPageView: UIView, PageViewType {
    var title: String {
        viewModel.navigationTitle
    }
    private (set) var viewModel: AssetsPageViewModel {
        didSet {
            viewModel.searchFilter = oldValue.searchFilter
        }
    }
    weak var delegate: AssetsPageViewDelegate?

    var rightBarButtonItem: UIBarButtonItem?

    private lazy var gridLayout: UICollectionViewLayout = {
        return UICollectionViewLayout.createGridLayout()
    }()

    private lazy var listLayout: UICollectionViewLayout = {
        return UICollectionViewLayout.createListLayout()
    }()

    private (set) lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = viewModel.backgroundColor
        collectionView.register(TokenCardContainerCollectionViewCell.self)
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        return collectionView
    }()
    private lazy var factory: TokenCardTableViewCellFactory = {
        TokenCardTableViewCellFactory()
    }()

    private (set) lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        UISearchBar.configure(searchBar: searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.returnKeyType = .done
        searchBar.enablesReturnKeyAutomatically = false
        if let textField = searchBar.textField {
            textField.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(doneButtonTapped), self)
        }
        return searchBar
    }()

    private let assetDefinitionStore: AssetDefinitionStore
    private var dataSource: TokenHoldersDataSource!

    init(assetDefinitionStore: AssetDefinitionStore, viewModel: AssetsPageViewModel) {
        self.viewModel = viewModel

        self.assetDefinitionStore = assetDefinitionStore
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = viewModel.backgroundColor

        addSubview(collectionView)
        addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: Style.SearchBar.height),
            
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        fixCollectionViewBackgroundColor()

        applyLayout(viewModel.selection)

        emptyView = EmptyView.filterTokenHoldersEmptyView()
        configureDataSource()
    }

    private func configureDataSource() {
        let assetDefinitionStore = assetDefinitionStore
        dataSource = TokenHoldersDataSource(collectionView: collectionView) { [weak self] cv, indexPath, tokenHolder -> TokenCardContainerCollectionViewCell? in
            guard let strongSelf = self else { return nil }

            let cell: TokenCardContainerCollectionViewCell = cv.dequeueReusableCell(for: indexPath)
            TokenCardContainerCollectionViewCell.configureSeparatorLines(selection: strongSelf.viewModel.selection, cell)
            cell.containerEdgeInsets = .zero

            let subview: TokenCardViewType = strongSelf.factory.create(for: tokenHolder, layout: strongSelf.viewModel.selection, gridEdgeInsets: .zero)
            cell.configure(subview: subview)
            cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: cv.frame.width, tokenView: .viewIconified), tokenId: tokenHolder.tokenId, assetDefinitionStore: assetDefinitionStore)

            return cell
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateLayout()
    }

    func configure(viewModel: AssetsPageViewModel) {
        let prevViewModel = self.viewModel
        self.viewModel = viewModel

        configureLayout(selection: viewModel.selection, prevSelection: prevViewModel.selection)
        reload(animatingDifferences: true)
    }

    private func invalidateDataSource(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<AssetsPageViewModel.AssetsSection, TokenHolder>()
        snapshot.appendSections([.assets])
        snapshot.appendItems(viewModel.filteredTokenHolders)

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
        invalidateLayout()
    }

    private func configureLayout(selection: GridOrListSelectionState, prevSelection: GridOrListSelectionState, animated: Bool = false) {
        guard selection.rawValue != prevSelection.rawValue else { return }

        applyLayout(selection)
        invalidateLayout()

        NotificationCenter.default.post(name: .invalidateLayout, object: collectionView, userInfo: ["selection": selection])
    }

    private func applyLayout(_ selection: GridOrListSelectionState) {
        switch selection {
        case .grid:
            collectionView.collectionViewLayout = gridLayout
            collectionView.contentInset = .init(top: 0, left: 0, bottom: 16, right: 0)
        case .list:
            collectionView.collectionViewLayout = listLayout
            collectionView.contentInset = .zero
        }
    }

    private func invalidateLayout() {
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func fixCollectionViewBackgroundColor() {
        let v = UIView()
        v.backgroundColor = viewModel.backgroundColor
        collectionView.backgroundColor = viewModel.backgroundColor
        collectionView.backgroundView = v
    }

    func reload(animatingDifferences: Bool) {
        startLoading(animated: false)
        invalidateDataSource(animatingDifferences: animatingDifferences)
        endLoading(animated: false)
    }

    @objc func doneButtonTapped() {
        endEditing(true)
    } 
}

extension AssetsPageView: StatefulViewController {
    func hasContent() -> Bool {
        return !viewModel.filteredTokenHolders.isEmpty
    }
}

extension UICollectionViewLayout {
    static func createGridLayout(spacing: CGFloat = 16, heightDimension: CGFloat = 220) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
            let iosVersionRelatedFractionalWidthForGrid: CGFloat = 1.0

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(iosVersionRelatedFractionalWidthForGrid), heightDimension: .absolute(heightDimension))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
            group.interItemSpacing = .fixed(spacing)
            group.contentInsets = NSDirectionalEdgeInsets(top: spacing, leading: spacing, bottom: 0, trailing: spacing)

            return NSCollectionLayoutSection(group: group)
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        layout.configuration = config

        return layout
    }

    static func createListLayout(spacing: CGFloat = 16, heightDimension: CGFloat = 96) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(heightDimension))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.contentInsets = .zero

            return NSCollectionLayoutSection(group: group)
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        layout.configuration = config

        return layout
    }
}

extension AssetsPageView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let tokenHolder = viewModel.item(atIndexPath: indexPath) else { return }
        delegate?.assetsPageView(self, didSelectTokenHolder: tokenHolder)
    }
}

extension UISearchBar {

    var textField: UITextField? {
        return getTextField(inViews: subviews)
    }

    private func getTextField(inViews views: [UIView]?) -> UITextField? {
        guard let views = views else { return nil }

        for view in views {
            if let textField = (view as? UITextField) ?? getTextField(inViews: view.subviews) {
                return textField
            }
        }

        return nil
    }
}
