// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt
import StatefulViewController
import AlphaWalletFoundation

protocol ActivitiesViewControllerDelegate: AnyObject {
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
    func didPressTransaction(transaction: Transaction, in viewController: ActivitiesViewController)
}

class ActivitiesViewController: UIViewController {
    private var viewModel: ActivitiesViewModel
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private lazy var bottomConstraint: NSLayoutConstraint = {
        return activitiesView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }()
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    private var activitiesView: ActivitiesView
    weak var delegate: ActivitiesViewControllerDelegate?

    init(analytics: AnalyticsLogger, keystore: Keystore, wallet: Wallet, viewModel: ActivitiesViewModel, sessionsProvider: SessionsProvider, assetDefinitionStore: AssetDefinitionStore, tokenImageFetcher: TokenImageFetcher) {
        self.viewModel = viewModel
        searchController = UISearchController(searchResultsController: nil)
        activitiesView = ActivitiesView(
            analytics: analytics,
            keystore: keystore,
            wallet: wallet,
            viewModel: viewModel,
            sessionsProvider: sessionsProvider,
            assetDefinitionStore: assetDefinitionStore,
            tokenImageFetcher: tokenImageFetcher)
        super.init(nibName: nil, bundle: nil)

        activitiesView.delegate = self
        keyboardChecker.constraints = [bottomConstraint]

        view.addSubview(activitiesView)

        NSLayoutConstraint.activate([
            activitiesView.topAnchor.constraint(equalTo: view.topAnchor),
            activitiesView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            activitiesView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
        ])

        setupFilteringWithKeyword()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)
    }

    deinit {
        activitiesView.resetStatefulStateToReleaseObjectToAvoidMemoryLeak()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardChecker.viewWillAppear()
        navigationItem.largeTitleDisplayMode = .always
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //NOTE: we call it here to show empty view if needed, as the reason that we don't have manually called callback where we can handle that loaded activities
        //next time view will be updated when configure with viewModel method get called.
        activitiesView.endLoading()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    func configure(viewModel: ActivitiesViewModel) {
        self.viewModel = viewModel

        title = R.string.localizable.activityTabbarItemTitle()
        view.backgroundColor = viewModel.backgroundColor
        activitiesView.configure(viewModel: viewModel)
        activitiesView.applySearch(keyword: searchController.searchBar.text)

        activitiesView.endLoading()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLayoutSubviews() {
        configureSearchBarOnce()
    }
}

extension ActivitiesViewController: ActivitiesViewDelegate {
    func didPressActivity(activity: Activity, in view: ActivitiesView) {
        delegate?.didPressActivity(activity: activity, in: self)
    }

    func didPressTransaction(transaction: Transaction, in view: ActivitiesView) {
        delegate?.didPressTransaction(transaction: transaction, in: self)
    }
}

extension ActivitiesViewController: UISearchResultsUpdating {
    //At least on iOS 13 beta on a device. updateSearchResults(for:) is called when we set `searchController.isActive = false` to dismiss search (because user tapped on a filter), but the value of `searchController.isActive` remains `false` during the call, hence the async.
    //This behavior is not observed in iOS 12, simulator
    public func updateSearchResults(for searchController: UISearchController) {
        processSearchWithKeywords()
    }

    private func processSearchWithKeywords() {
        activitiesView.applySearch(keyword: searchController.searchBar.text)
        activitiesView.endLoading()
    }

}

extension ActivitiesViewController {

    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = viewModel.backgroundColor
    }

    private func setupFilteringWithKeyword() {
        wireUpSearchController()
        doNotDimTableViewToReuseTableForFilteringResult()
        makeSwitchToAnotherTabWorkWhileFiltering()
    }

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.obscuresBackgroundDuringPresentation = false
    }

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true

        UISearchBar.configure(searchBar: searchController.searchBar)
    }
}
