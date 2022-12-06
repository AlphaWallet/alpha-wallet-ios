//
//  AnalyticsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.01.2022.
//

import UIKit
import AlphaWalletFoundation

class AnalyticsViewController: UIViewController {

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        return label
    }()

    private let viewModel: AnalyticsViewModel
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView(viewModel: .init(backgroundColor: viewModel.backgroundColor))
        return view
    }()
    private lazy var switchView = SwitchView(edgeInsets: .init(top: 0, left: DataEntry.Metric.Analytics.edgeInsets.left, bottom: 0, right: DataEntry.Metric.Analytics.edgeInsets.right), height: 60)

    init(viewModel: AnalyticsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.anchorsConstraint(to: view, edgeInsets: .init(top: DataEntry.Metric.Analytics.spacing, left: 0, bottom: 0, right: 0))
        ])

        let labeledSwitchViewContainerView = TokensViewController.ContainerView<SwitchView>(subview: switchView)
        labeledSwitchViewContainerView.useSeparatorLine = true

        containerView.stackView.spacing = DataEntry.Metric.Analytics.spacing
        containerView.stackView.addArrangedSubviews([
            imageView,
            [
                .spacerWidth(DataEntry.Metric.Analytics.edgeInsets.left),
                descriptionLabel,
                .spacerWidth(DataEntry.Metric.Analytics.edgeInsets.right)
            ].asStackView(axis: .horizontal, alignment: .center),
            labeledSwitchViewContainerView
        ])
        switchView.delegate = self
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure(viewModel: viewModel)
    }

    private func configure(viewModel: AnalyticsViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.title
        imageView.image = viewModel.image
        descriptionLabel.attributedText = viewModel.attributedDescriptionString
        switchView.configure(viewModel: viewModel.switchViewModel)
    }
}

extension AnalyticsViewController: SwitchViewDelegate {
    func toggledTo(_ newValue: Bool, headerView: SwitchView) {
        viewModel.set(sendAnalyticsEnabled: newValue)
    }
}
