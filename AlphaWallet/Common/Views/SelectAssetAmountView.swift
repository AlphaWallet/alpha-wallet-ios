//
//  TokenCardSelectionAmountView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.08.2021.
//

import UIKit
import Combine

class SelectAssetAmountView: UIView {

    private (set) var plusButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(R.image.iconsSystemAddBorderCircle(), for: .normal)
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }

        return button
    }()

    private (set) var minusButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(R.image.iconsSystemCircleMinue(), for: .normal)
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }

        return button
    }()

    private (set) var countLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Configuration.Font.accessory
        label.textAlignment = .center
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.bold(size: 24)

        return label
    }()
    private var cancellable = Set<AnyCancellable>()

    let viewModel: SelectAssetViewModel

    init(viewModel: SelectAssetViewModel, edgeInsets: UIEdgeInsets = .zero) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        let centeredView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false

            let stackView = [minusButton, countLabel, plusButton].asStackView(axis: .horizontal, spacing: 10)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stackView)

            NSLayoutConstraint.activate([
                countLabel.widthAnchor.constraint(equalToConstant: 50),
                stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])

            return view
        }()

        addSubview(centeredView)
        NSLayoutConstraint.activate([
            centeredView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            centeredView.heightAnchor.constraint(equalToConstant: 70)
        ])

        backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: SelectAssetViewModel) {
        let input = SelectAssetViewModelInput(
            increase: plusButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher(),
            decrease: minusButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.text
            .assign(to: \.text, on: countLabel)
            .store(in: &cancellable)
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

extension Publisher where Failure == Never {
    func assign<Root: AnyObject>(to path: ReferenceWritableKeyPath<Root, Output?>, on instance: Root) -> Cancellable {
        sink { instance[keyPath: path] = $0 }
    }
}
