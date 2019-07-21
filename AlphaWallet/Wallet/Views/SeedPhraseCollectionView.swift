// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol SeedPhraseCollectionViewDelegate: class {
    func didTap(word: String, atIndex index: Int, inCollectionView: SeedPhraseCollectionView)
}

class SeedPhraseCollectionView: UICollectionView {
    var viewModel: SeedPhraseCollectionViewModel = .init(isSelectable: true, shouldShowSequenceNumber: true) {
        didSet {
            reloadData()
        }
    }
    weak var seedPhraseDelegate: SeedPhraseCollectionViewDelegate?

    convenience init() {
        let layout = CollectionViewLeftAlignedFlowLayout()
        layout.sectionInset = .init(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumInteritemSpacing = 7
        layout.minimumLineSpacing = 7
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        self.init(frame: .zero, collectionViewLayout: layout)

        register(SeedPhraseCell.self, forCellWithReuseIdentifier: SeedPhraseCell.identifier)
        dataSource = self
        delegate = self
    }

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = viewModel.backgroundColor
        reloadData()
    }
}

extension SeedPhraseCollectionView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.seedPhraseWordCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SeedPhraseCell.identifier, for: indexPath) as! SeedPhraseCell
        let index = indexPath.item
        let word = viewModel.seedPhraseWord(atIndex: index)
        let isSelected = viewModel.isWordSelected(atIndex: index)
        cell.configure(viewModel: .init(word: word, isSelected: isSelected, index: viewModel.shouldShowSequenceNumber ? index : nil))
        return cell
    }
}

extension SeedPhraseCollectionView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard viewModel.isSelectable else { return }
        let index = indexPath.item
        guard !viewModel.isWordSelected(atIndex: index) else { return }
        viewModel.selectWord(atIndex: index)
        seedPhraseDelegate?.didTap(word: viewModel.seedPhraseWord(atIndex: index), atIndex: index, inCollectionView: self)
    }
}
