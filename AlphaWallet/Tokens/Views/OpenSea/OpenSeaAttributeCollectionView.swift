//
//  OpenSeaAttributeCollectionView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.01.2022.
//

import UIKit

struct OpenSeaOpenSeaAttributeCollectionViewModel {
    var backgroundColor: UIColor = Colors.appBackground
    var attributes: [OpenSeaNonFungibleTokenAttributeCellViewModel]
}

class OpenSeaAttributeCollectionView: UIView {

    private (set) var viewModel: OpenSeaOpenSeaAttributeCollectionViewModel

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        //3-column for iPhone 6s and above, 2-column for iPhone 5
        layout.itemSize = CGSize(width: 105, height: 30)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 00

        let view = SelfResizableCollectionView(frame: .zero, collectionViewLayout: layout)
        view.register(OpenSeaNonFungibleTokenTraitCell.self)
        view.isUserInteractionEnabled = false
        view.dataSource = self
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    init(viewModel: OpenSeaOpenSeaAttributeCollectionViewModel, edgeInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 16, right: 16)) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(collectionView)

        NSLayoutConstraint.activate(collectionView.anchorsConstraint(to: self, edgeInsets: edgeInsets))

        configure(viewModel: viewModel)
    }

    func configure(viewModel: OpenSeaOpenSeaAttributeCollectionViewModel) {
        self.viewModel = viewModel
        
        collectionView.backgroundColor = viewModel.backgroundColor
        backgroundColor = viewModel.backgroundColor

        collectionView.reloadData()
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

extension OpenSeaAttributeCollectionView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.attributes.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: OpenSeaNonFungibleTokenTraitCell = collectionView.dequeueReusableCell(for: indexPath)
        let viewModel = self.viewModel.attributes[indexPath.row]
        cell.configure(viewModel: .init(name: viewModel.name, value: viewModel.value))

        return cell
    }
}

