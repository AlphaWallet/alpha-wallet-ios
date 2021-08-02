//
//  ActivityPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit
import StatefulViewController

struct ActivityPageViewModel {
    var title: String {
        return R.string.localizable.tokenTabActivity()
    }

    let activitiesViewModel: ActivitiesViewModel

    init(activitiesViewModel: ActivitiesViewModel) {
        self.activitiesViewModel = activitiesViewModel
    }
}

protocol ActivityPageViewDelegate: class {
    func didTap(activity: Activity, in view: ActivityPageView)
    func didTap(transaction: TransactionInstance, in view: ActivityPageView)
}

class ActivityPageView: UIView, TokenPageViewType {

    var title: String {
        viewModel.title
    }

    private lazy var activitiesView: ActivitiesView = {
        let view = ActivitiesView(viewModel: viewModel.activitiesViewModel, sessions: sessions)
        view.delegate = self
        return view
    }()
    var viewModel: ActivityPageViewModel
    private let sessions: ServerDictionary<WalletSession>
    weak var delegate: ActivityPageViewDelegate?

    init(viewModel: ActivityPageViewModel, sessions: ServerDictionary<WalletSession>) {
        self.viewModel = viewModel
        self.sessions = sessions
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(activitiesView)

        NSLayoutConstraint.activate([
            activitiesView.anchorsConstraint(to: self)
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: ActivityPageViewModel) {
        self.viewModel = viewModel
        activitiesView.configure(viewModel: viewModel.activitiesViewModel)
        activitiesView.applySearch(keyword: nil)

        activitiesView.endLoading()
    }
}

extension ActivityPageView: ActivitiesViewDelegate {

    func didPressActivity(activity: Activity, in view: ActivitiesView) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didPressTransaction(transaction: TransactionInstance, in view: ActivitiesView) {
        delegate?.didTap(transaction: transaction, in: self)
    }
}
