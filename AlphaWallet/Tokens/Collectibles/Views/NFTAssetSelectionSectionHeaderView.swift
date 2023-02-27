//
//  NFTAssetSelectionSectionHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.11.2021.
//

import UIKit
import AlphaWalletFoundation
import Combine

protocol SelectionPositioningView: AnyObject {
    var positioningView: UIView { get }
}

extension NFTAssetSelectionViewController {

    class NFTAssetSelectionSectionHeaderView: UITableViewHeaderFooterView {

        private lazy var selectAllAssetsView: SelectAllAssetsView = {
            let view = SelectAllAssetsView()

            return view
        }()

        private var topSeparatorView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false

            return view
        }()

        var publisher: AnyPublisher<Void, Never> {
            selectAllAssetsView.selectAllButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher()
        }
        var cancellable = Set<AnyCancellable>()

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)

            addSubview(selectAllAssetsView)
            addSubview(topSeparatorView)

            NSLayoutConstraint.activate([
                selectAllAssetsView.anchorsConstraint(to: self, edgeInsets: .init(top: DataEntry.Metric.TableView.groupedTableCellSeparatorHeight, left: 0, bottom: DataEntry.Metric.TableView.groupedTableCellSeparatorHeight, right: 0)),

                topSeparatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
                topSeparatorView.widthAnchor.constraint(equalTo: widthAnchor),
                topSeparatorView.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TableView.groupedTableCellSeparatorHeight),
                topSeparatorView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        required init?(coder: NSCoder) {
            return nil
        }

        func configure(viewModel: NFTAssetSelectionSectionHeaderViewModel) {
            topSeparatorView.backgroundColor = viewModel.separatorColor
            selectAllAssetsView.configure(viewModel: viewModel.selectAllAssetsViewModel)
        }
    }

    struct NFTAssetSelectionSectionHeaderViewModel {
        let text: String
        var selectAllAssetsViewModel: SelectAllAssetsViewModel
        var separatorColor: UIColor = Configuration.Color.Semantic.tableViewSeparator
        var isSelectAllHidden: Bool = false

        init(name: String, backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground) {
            self.text = name
            self.selectAllAssetsViewModel = .init(text: text, backgroundColor: backgroundColor, isSelectAllHidden: isSelectAllHidden)
        }
    }
}

