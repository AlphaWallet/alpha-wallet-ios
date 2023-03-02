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

protocol NFTAssetsPageViewDelegate: AnyObject {
    func nftAssetsPageView(_ view: NFTAssetsPageView, didSelectTokenHolder tokenHolder: TokenHolder)
}

class NFTAssetsPageView: UIView, PageViewType {
    private lazy var gridLayout: UICollectionViewLayout = {
        return UICollectionViewLayout.createGridLayout(contentInsets: viewModel.contentInsetsForGridLayout, spacing: viewModel.spacingForGridLayout, heightDimension: viewModel.heightDimensionForGridLayout, colums: viewModel.columsForGridLayout)
    }()

    private lazy var listLayout: UICollectionViewLayout = {
        return UICollectionViewLayout.createListLayout()
    }()

    private (set) lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
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

    private lazy var dataSource: DataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private var cancelable = Set<AnyCancellable>()

    var title: String { viewModel.title }
    let viewModel: NFTAssetsPageViewModel
    weak var delegate: NFTAssetsPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?

    init(tokenCardViewFactory: TokenCardViewFactory, viewModel: NFTAssetsPageViewModel) {
        self.viewModel = viewModel
        self.tokenCardViewFactory = tokenCardViewFactory
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        addSubview(collectionView)
        addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.SearchBar.height),
            
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        fixCollectionViewBackgroundColor()

        applyLayout(viewModel.layout)

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
        willAppear.send(())
    }

    func bind(viewModel: NFTAssetsPageViewModel) {
        let input = NFTAssetsPageViewModelInput(willAppear: willAppear.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self, dataSource] state in
                self?.startLoading(animated: false)
                dataSource.apply(state.snapshot, animatingDifferences: state.animatingDifferences)
                self?.invalidateLayout()
                self?.endLoading(animated: false)
            }.store(in: &cancelable)

        output.layout
            .sink { [weak self] in self?.configureLayout(layout: $0) }
            .store(in: &cancelable)
    }

    private func configureLayout(layout: GridOrListLayout) {
        applyLayout(layout)
        invalidateLayout()

        NotificationCenter.default.post(name: .invalidateLayout, object: collectionView, userInfo: ["layout": layout])
    }

    private func applyLayout(_ selection: GridOrListLayout) {
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
        v.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        collectionView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
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
    private typealias DataSource = UICollectionViewDiffableDataSource<NFTAssetsPageViewModel.Section, TokenHolder>

    private func makeDataSource() -> DataSource {
        DataSource(collectionView: collectionView) { [viewModel, tokenCardViewFactory] cv, indexPath, tokenHolder -> ContainerCollectionViewCell? in
            let cell: ContainerCollectionViewCell = cv.dequeueReusableCell(for: indexPath)
            ContainerCollectionViewCell.configureSeparatorLines(layout: viewModel.layout, cell)
            cell.containerEdgeInsets = .zero

            let subview: TokenCardViewRepresentable = tokenCardViewFactory.createTokenCardView(for: tokenHolder, layout: viewModel.layout, gridEdgeInsets: .zero)
            subview.configure(tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId)

            cell.configure(subview: subview)
            cell.configure()

            return cell
        }
    }

}
