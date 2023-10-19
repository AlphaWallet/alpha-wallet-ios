//
//  SelectedSwapToolsCollectionView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import UIKit
import Combine
import StatefulViewController

final class SelectedSwapToolsCollectionView: UIView {
    private let collectionView: UICollectionView = {
        let layout = CollectionViewLeftAlignedFlowLayout()
        layout.sectionInset = .init(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumInteritemSpacing = 7
        layout.minimumLineSpacing = 7
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(SwapToolCollectionViewCell.self)
        collectionView.backgroundColor = Configuration.Color.Semantic.tableViewBackground

        return collectionView
    }()
    private lazy var dataSource: SelectedSwapToolsCollectionViewModel.DataSource = makeDataSource()
    private var cancelable = Set<AnyCancellable>()
    private static let fallbackHeight: CGFloat = 60
    private lazy var collectionViewHeightConstraint = collectionView.heightAnchor.constraint(equalToConstant: SelectedSwapToolsCollectionView.fallbackHeight)
    private let viewModel: SelectedSwapToolsCollectionViewModel
    private let willAppear: AnyPublisher<Void, Never>

    init(viewModel: SelectedSwapToolsCollectionViewModel, willAppear: AnyPublisher<Void, Never>) {
        self.viewModel = viewModel
        self.willAppear = willAppear
        super.init(frame: .zero)

        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.anchorsConstraint(to: self, edgeInsets: .init(top: 5, left: 0, bottom: 5, right: 0)),
            collectionViewHeightConstraint
        ])

        collectionView.publisher(for: \.contentSize)
            .map { $0.height == .zero ? SelectedSwapToolsCollectionView.fallbackHeight : $0.height }
            .removeDuplicates()
            .sink { [collectionViewHeightConstraint] in collectionViewHeightConstraint.constant = $0 }
            .store(in: &cancelable)

        bind(viewModel: viewModel)
        emptyView = EmptyView.selectedSwapToolsEmptyView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bind(viewModel: SelectedSwapToolsCollectionViewModel) {
        backgroundColor = Configuration.Color.Semantic.tableViewBackground

        let willAppear = willAppear
            .handleEvents(receiveOutput: { [weak self] _ in self?.startLoading() })
            .eraseToAnyPublisher()

        let input = SelectedSwapToolsCollectionViewModelInput(willAppear: willAppear)
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self] in
                self?.dataSource.apply($0.snapshot, animatingDifferences: false)
                self?.collectionView.flashScrollIndicators()
                self?.endLoading()
            }.store(in: &cancelable)
    }
}

extension SelectedSwapToolsCollectionView: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension SelectedSwapToolsCollectionView {
    private func makeDataSource() -> SelectedSwapToolsCollectionViewModel.DataSource {
        SelectedSwapToolsCollectionViewModel.DataSource(collectionView: collectionView) { collectionView, indexPath, viewModel -> SwapToolCollectionViewCell in
            let cell: SwapToolCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}
