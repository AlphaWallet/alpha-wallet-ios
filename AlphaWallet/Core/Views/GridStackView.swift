//
//  GridStackView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.03.2022.
//

import UIKit

struct GridViewModel {
    var columns: Int = 2
    var spacing: CGFloat = 10
    var edgeInsets: UIEdgeInsets = .zero
}

class GridStackView: UIView {
    private let viewModel: GridViewModel
    private lazy var root: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = viewModel.spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    init(viewModel: GridViewModel = .init()) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([root.anchorsConstraint(to: self, edgeInsets: viewModel.edgeInsets)])
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = viewModel.spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }

    func set(subviews: [UIView]) {
        root.removeAllArrangedSubviews()
        var index: Int = 0
        for subviews in subviews.chunked(into: viewModel.columns) {
            let child = createStackView()

            for view in subviews {
                view.translatesAutoresizingMaskIntoConstraints = false
                child.addArrangedSubview(view)
            }
            let dummyViews = viewModel.columns - subviews.count
            if dummyViews > 0 {
                var views = Array(repeating: UIView(), count: dummyViews)
                views = views.map { view in
                    view.translatesAutoresizingMaskIntoConstraints = false
                    view.backgroundColor = .clear
                    return view
                }

                child.addArrangedSubviews(views)
            }

            index += 1
            root.addArrangedSubview(child)
        }
    }
}
