//
//  NFTAssetsPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import Combine
import StatefulViewController 
import AlphaWalletFoundation

extension NSNotification.Name {
    static let invalidateLayout = NSNotification.Name(rawValue: "InvalidateLayout")
}

protocol NFTAssetsPageViewDelegate: class {
    func nftAssetsPageView(_ view: NFTAssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder)
}
typealias TokenHoldersDataSource = UICollectionViewDiffableDataSource<NFTAssetsPageViewModel.AssetsSection, TokenHolder>

class NFTAssetsPageView: UIView, PageViewType {
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

    private lazy var dataSource: TokenHoldersDataSource = makeDataSource()
    private let appear = PassthroughSubject<Void, Never>()
    private var cancelable = Set<AnyCancellable>()

    var title: String {
        viewModel.navigationTitle
    }
    let viewModel: NFTAssetsPageViewModel
    weak var delegate: NFTAssetsPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?

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
        bind(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateLayout()
    }

    func viewWillAppear() {
        appear.send(())
    }

    func bind(viewModel: NFTAssetsPageViewModel) {
        let input = NFTAssetsPageViewModelInput(appear: appear.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState.sink { [weak self] state in
            self?.startLoading(animated: false)
            self?.invalidateDataSource(with: state)
            self?.endLoading(animated: false)
        }.store(in: &cancelable)

        output.selection.sink { [weak self] selection in
            self?.configureLayout(selection: selection)
        }.store(in: &cancelable)
    }

    private func invalidateDataSource(with state: NFTAssetsPageViewModel.ViewState) {
        var snapshot = NSDiffableDataSourceSnapshot<NFTAssetsPageViewModel.AssetsSection, TokenHolder>()
        snapshot.appendSections(state.sections.map { $0.section })
        for section in state.sections {
            snapshot.appendItems(section.views)
        }

        dataSource.apply(snapshot, animatingDifferences: state.animatingDifferences)
        invalidateLayout()
    }

    private func configureLayout(selection: GridOrListSelectionState) {
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

    @objc func doneButtonTapped() {
        endEditing(true)
    }

    func resetStatefulStateToReleaseObjectToAvoidMemoryLeak() {
        // NOTE: Stateful lib set to object state machine that later causes ref cycle when applying it to view
        // here we release all associated objects to release state machine
        // this method callget get called while parent's view deinit get called
        objc_removeAssociatedObjects(self)
    }
}

extension NFTAssetsPageView: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension NFTAssetsPageView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let tokenHolder = dataSource.itemIdentifier(for: indexPath) else { return }

        delegate?.nftAssetsPageView(self, didSelectTokenHolder: tokenHolder)
    }
}
extension NFTAssetsPageView {
    func makeDataSource() -> UICollectionViewDiffableDataSource<NFTAssetsPageViewModel.AssetsSection, TokenHolder> {
        TokenHoldersDataSource(collectionView: collectionView) { [weak self] cv, indexPath, tokenHolder -> ContainerCollectionViewCell? in
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

}
