//
//  WhatsNewListingViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 29/11/21.
//

import UIKit

class WhatsNewListingViewController: UIViewController {
    let viewModel: WhatsNewListingViewModel

    private lazy var containerView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.translatesAutoresizingMaskIntoConstraints = false
        view.spacing = 0

        return view
    }()
    
    init(viewModel: WhatsNewListingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.anchorsConstraint(to: view)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    private func configureView() {
        var views: [UIView] = [.spacer(height: 30)]
        views.append(WhatsNewHeaderView(title: viewModel.title))
        for entry in viewModel.entries {
            views.append(WhatsNewSubHeaderView(title: entry.title))
            for change in entry.changes {
                views.append(WhatsNewEntryView(entryString: change, shouldShowCheckmarks: viewModel.shouldShowCheckmarks))
            }
        }
        views += [.spacer(height: 30)]

        containerView.addArrangedSubviews(views)
        view.backgroundColor = Configuration.Color.Semantic.dialogBackground
    }
}
