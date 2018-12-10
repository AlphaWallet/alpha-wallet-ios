// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class DappsHomeViewControllerHeaderView: UICollectionReusableView {
    private let stackView = [].asStackView(axis: .vertical, contentHuggingPriority: .required, alignment: .center)
    private let headerView = DappsHomeHeaderView()

    let myDappsButton = DappButton()
    let discoverDappsButton = DappButton()
    let historyButton = DappButton()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let buttonsStackView = [
            myDappsButton,
            .spacerWidth(40),
            discoverDappsButton,
            .spacerWidth(40),
            historyButton
        ].asStackView(distribution: .equalSpacing, contentHuggingPriority: .required)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubviews([
            headerView,
            .spacer(height: 30),
            buttonsStackView,
        ])
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 50),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -50),

            myDappsButton.widthAnchor.constraint(equalTo: discoverDappsButton.widthAnchor),
            myDappsButton.widthAnchor.constraint(equalTo: historyButton.widthAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DappsHomeViewControllerHeaderViewViewModel = .init()) {
        backgroundColor = viewModel.backgroundColor

        headerView.configure(viewModel: .init(title: viewModel.title))

        myDappsButton.configure(viewModel: .init(image: viewModel.myDappsButtonImage, title: viewModel.myDappsButtonTitle))

        discoverDappsButton.configure(viewModel: .init(image: viewModel.discoverButtonImage, title: viewModel.discoverButtonTitle))

        historyButton.configure(viewModel: .init(image: viewModel.historyButtonImage, title: viewModel.historyButtonTitle))
    }
}
