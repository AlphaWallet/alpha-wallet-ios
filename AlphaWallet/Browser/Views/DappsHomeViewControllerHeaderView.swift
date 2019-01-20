// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol DappsHomeViewControllerHeaderViewDelegate: class {
    func didExitEditMode(inHeaderView: DappsHomeViewControllerHeaderView)
}

class DappsHomeViewControllerHeaderView: UICollectionReusableView {
    private let stackView = [].asStackView(axis: .vertical, contentHuggingPriority: .required, alignment: .center)
    private let headerView = DappsHomeHeaderView()
    private let exitEditingModeButton = UIButton(type: .system)

    weak var delegate: DappsHomeViewControllerHeaderViewDelegate?
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

        exitEditingModeButton.addTarget(self, action: #selector(exitEditMode), for: .touchUpInside)
        exitEditingModeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(exitEditingModeButton)

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
            stackView.bottomAnchor.constraint(equalTo: exitEditingModeButton.topAnchor, constant: -10),

            myDappsButton.widthAnchor.constraint(equalTo: discoverDappsButton.widthAnchor),
            myDappsButton.widthAnchor.constraint(equalTo: historyButton.widthAnchor),

            exitEditingModeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            exitEditingModeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DappsHomeViewControllerHeaderViewViewModel = .init(isEditing: false)) {
        backgroundColor = viewModel.backgroundColor

        headerView.configure(viewModel: .init(title: viewModel.title))

        myDappsButton.configure(viewModel: .init(image: viewModel.myDappsButtonImage, title: viewModel.myDappsButtonTitle))

        discoverDappsButton.configure(viewModel: .init(image: viewModel.discoverButtonImage, title: viewModel.discoverButtonTitle))

        historyButton.configure(viewModel: .init(image: viewModel.historyButtonImage, title: viewModel.historyButtonTitle))

        if viewModel.isEditing {
            exitEditingModeButton.isHidden = false
            exitEditingModeButton.setTitle(R.string.localizable.done().localizedUppercase, for: .normal)
            exitEditingModeButton.titleLabel?.font = Fonts.bold(size: 12)

            myDappsButton.isEnabled = false
            discoverDappsButton.isEnabled = false
            historyButton.isEnabled = false
        } else {
            exitEditingModeButton.isHidden = true

            myDappsButton.isEnabled = true
            discoverDappsButton.isEnabled = true
            historyButton.isEnabled = true
        }
    }

    @objc private func exitEditMode() {
        configure(viewModel: .init(isEditing: false))
        delegate?.didExitEditMode(inHeaderView: self)
    }
}
