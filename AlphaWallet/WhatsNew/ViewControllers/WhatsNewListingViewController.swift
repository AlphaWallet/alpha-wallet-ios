//
//  WhatsNewListingViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 29/11/21.
//

import UIKit

class WhatsNewListingViewController: ModalViewController {
    let viewModel: WhatsNewListingViewModel
    weak var whatsNewListingDelegate: WhatsNewListingCoordinatorProtocol?

    init(viewModel: WhatsNewListingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        configureView()
        presentationDelegate = self
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    private func configureView() {
        var views: [UIView] = []
        views.append(WhatsNewHeaderView(title: viewModel.title))
        for entry in viewModel.entries {
            views.append(WhatsNewSubHeaderView(title: entry.title))
            for change in entry.changes {
                views.append(WhatsNewEntryView(entryString: change, shouldShowCheckmarks: viewModel.shouldShowCheckmarks))
            }
        }
        stackView.addArrangedSubviews(views)
    }
}

extension WhatsNewListingViewController: ModalViewControllerDelegate {
    func didDismiss(_ controller: ModalViewController) {
        controller.dismissViewAnimated {
            controller.dismiss(animated: false) {
                self.whatsNewListingDelegate?.didDismiss(controller: self)
            }
        }
    }

    func didClose(_ controller: ModalViewController) {
        controller.dismissViewAnimated {
            controller.dismiss(animated: false) {
                self.whatsNewListingDelegate?.didDismiss(controller: self)
            }
        }
    }
}
