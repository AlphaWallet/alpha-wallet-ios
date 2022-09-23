//
//  WalletPupupViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit

protocol WalletPupupViewControllerDelegate: class {
    func didSelect(action: PupupAction, in viewController: WalletPupupViewController)
}

class WalletPupupViewController: UIViewController {
    private var viewModel: WalletPupupViewModel
    weak var delegate: WalletPupupViewControllerDelegate?

    private lazy var containerView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.translatesAutoresizingMaskIntoConstraints = false
        view.spacing = 0

        return view
    }()

    init(viewModel: WalletPupupViewModel = .init()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.anchorsConstraint(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        generateSubviews(viewModel: viewModel)
        configure(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: WalletPupupViewModel) {
        self.viewModel = viewModel
        view.backgroundColor = viewModel.backbroundColor
    }

    private func generateSubviews(viewModel: WalletPupupViewModel) {
        containerView.removeAllArrangedSubviews()

        var subviews: [UIView] = []
        subviews += [.spacer(height: 20)]

        for each in viewModel.actions {
            let view = WalletPupupItemView(edgeInsets: .init(top: 10, left: 20, bottom: 10, right: 20))
            view.configure(viewModel: .init(title: each.title, description: each.description, icon: each.icon))
            subviews.append(view)
            subviews.append(.spacer(height: 1, backgroundColor: viewModel.viewsSeparatorColor))

            UITapGestureRecognizer(addToView: view) { [weak self] in
                guard let strongSelf = self, let delegate = strongSelf.delegate else { return }

                delegate.didSelect(action: each, in: strongSelf)
            }
        }
        subviews += [.spacer(height: 10, flexible: true)]

        containerView.addArrangedSubviews(subviews)
    }
}

extension WalletPupupViewController {

    private class WalletPupupItemView: HighlightableView {
        private lazy var titleLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            return label
        }()

        private lazy var descriptionLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            return label
        }()

        private lazy var iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
            imageView.widthAnchor.constraint(equalToConstant: 40).isActive = true

            return imageView
        }()

        init(edgeInsets: UIEdgeInsets) {
            super.init()
            self.translatesAutoresizingMaskIntoConstraints = false

            let cell = [titleLabel, descriptionLabel].asStackView(axis: .vertical)
            let stackView = [iconImageView, cell].asStackView(axis: .horizontal, spacing: 16, alignment: .center)
            stackView.translatesAutoresizingMaskIntoConstraints = false

            addSubview(stackView)
            NSLayoutConstraint.activate([
                stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets)
            ])
        }

        required init?(coder: NSCoder) {
            return nil
        }

        func configure(viewModel: WalletPupupItemViewModel) {
            titleLabel.attributedText = viewModel.attributedTitle
            descriptionLabel.attributedText = viewModel.attributedDescription
            iconImageView.image = viewModel.icon

            set(backgroundColor: viewModel.highlightedBackgroundColor, forState: .highlighted)
            set(backgroundColor: viewModel.normalBackgroundColor, forState: .normal)
        }
    }
}
