//
//  ActivitiesPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit
import StatefulViewController
import AlphaWalletFoundation

struct ActivityPageViewModel {
    var title: String {
        return R.string.localizable.tokenTabActivity()
    }

    let activitiesViewModel: ActivitiesViewModel

    init(activitiesViewModel: ActivitiesViewModel) {
        self.activitiesViewModel = activitiesViewModel
    }
}

protocol ActivitiesPageViewDelegate: AnyObject {
    func didTap(activity: Activity, in view: ActivitiesPageView)
    func didTap(transaction: Transaction, in view: ActivitiesPageView)
}

class ActivitiesPageView: UIView, PageViewType {

    var title: String { viewModel.title }

    private var activitiesView: ActivitiesView
    var viewModel: ActivityPageViewModel
    weak var delegate: ActivitiesPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?
    
    init(analytics: AnalyticsLogger,
         keystore: Keystore,
         wallet: Wallet,
         viewModel: ActivityPageViewModel,
         sessionsProvider: SessionsProvider,
         assetDefinitionStore: AssetDefinitionStore,
         tokenImageFetcher: TokenImageFetcher) {

        self.viewModel = viewModel
        activitiesView = ActivitiesView(
            analytics: analytics,
            keystore: keystore,
            wallet: wallet,
            viewModel: viewModel.activitiesViewModel,
            sessionsProvider: sessionsProvider,
            assetDefinitionStore: assetDefinitionStore,
            tokenImageFetcher: tokenImageFetcher)
        super.init(frame: .zero)

        activitiesView.delegate = self
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(activitiesView)

        NSLayoutConstraint.activate([activitiesView.anchorsConstraintSafeArea(to: self)])

        configure(viewModel: viewModel)
    }

    deinit {
        activitiesView.resetStatefulStateToReleaseObjectToAvoidMemoryLeak()
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

extension ActivitiesPageView: ActivitiesViewDelegate {

    func didPressActivity(activity: Activity, in view: ActivitiesView) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didPressTransaction(transaction: Transaction, in view: ActivitiesView) {
        delegate?.didTap(transaction: transaction, in: self)
    }
}
