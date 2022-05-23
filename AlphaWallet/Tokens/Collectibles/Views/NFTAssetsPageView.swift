//
//  NFTAssetsPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import StatefulViewController 

extension NSNotification.Name {
    static let invalidateLayout = NSNotification.Name(rawValue: "InvalidateLayout")
}

protocol NFTAssetsPageViewDelegate: class {
    func nftAssetsPageView(_ view: NFTAssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder)
}
typealias TokenHoldersDataSource = UICollectionViewDiffableDataSource<NFTAssetsPageViewModel.AssetsSection, TokenHolder>

class NFTAssetsPageView: UIView, PageViewType {
    var title: String {
        viewModel.navigationTitle
    }
    private (set) var viewModel: NFTAssetsPageViewModel {
        didSet { viewModel.searchFilter = oldValue.searchFilter }
    }
    weak var delegate: NFTAssetsPageViewDelegate?

    var rightBarButtonItem: UIBarButtonItem?

    private lazy var gridLayout: UICollectionViewLayout = {
        return UICollectionViewLayout.createGridLayout(contentInsets: viewModel.contentInsetsForGridLayout, spacing: viewModel.spacingForGridLayout, heightDimension: viewModel.heightDimensionForGridLayout, colums: viewModel.columsForGridLayout)
    }()

    private lazy var listLayout: UICollectionViewLayout = {
        return UICollectionViewLayout.createListLayout()
    }()

    private (set) lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = viewModel.backgroundColor
        collectionView.register(ContainerCollectionViewCell.self)
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        return collectionView
    }()
    private let tokenCardViewFactory: TokenCardViewFactory

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

    private var dataSource: TokenHoldersDataSource!

    init(tokenCardViewFactory: TokenCardViewFactory, viewModel: NFTAssetsPageViewModel) {
        self.viewModel = viewModel
        self.tokenCardViewFactory = tokenCardViewFactory
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
        dataSource = TokenHoldersDataSource(collectionView: collectionView) { [weak self] cv, indexPath, tokenHolder -> ContainerCollectionViewCell? in
            guard let strongSelf = self else { return nil }

            let cell: ContainerCollectionViewCell = cv.dequeueReusableCell(for: indexPath)
            ContainerCollectionViewCell.configureSeparatorLines(selection: strongSelf.viewModel.selection, cell)
            cell.containerEdgeInsets = .zero

            let subview: TokenCardViewType = strongSelf.tokenCardViewFactory.create(for: tokenHolder, layout: strongSelf.viewModel.selection, gridEdgeInsets: .zero)
            subview.configure(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId)

            cell.configure(subview: subview)
            cell.configure()

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

    func configure(viewModel: NFTAssetsPageViewModel) {
        let prevViewModel = self.viewModel
        self.viewModel = viewModel

        configureLayout(selection: viewModel.selection, prevSelection: prevViewModel.selection)
        reload(animatingDifferences: true)
    }

    private func invalidateDataSource(animatingDifferences: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<NFTAssetsPageViewModel.AssetsSection, TokenHolder>()
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

extension NFTAssetsPageView: StatefulViewController {
    func hasContent() -> Bool {
        return !viewModel.filteredTokenHolders.isEmpty
    }
}

extension NFTAssetsPageView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let tokenHolder = viewModel.tokenHolder(for: indexPath) else { return }
        delegate?.nftAssetsPageView(self, didSelectTokenHolder: tokenHolder)
    }
}
