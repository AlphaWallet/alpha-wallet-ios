// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt
import StatefulViewController

protocol ActivitiesViewControllerDelegate: AnyObject {
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController)
}

class ActivitiesViewController: UIViewController {
    private var viewModel: ActivitiesViewModel
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private var bottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    private var activitiesView: ActivitiesView
    weak var delegate: ActivitiesViewControllerDelegate?

    init(viewModel: ActivitiesViewModel, sessions: ServerDictionary<WalletSession>) {
        self.viewModel = viewModel
        searchController = UISearchController(searchResultsController: nil)
        activitiesView = ActivitiesView(viewModel: viewModel, sessions: sessions)
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.activityTabbarItemTitle()
        activitiesView.delegate = self
        view.backgroundColor = viewModel.backgroundColor

        bottomConstraint = activitiesView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        keyboardChecker.constraint = bottomConstraint

        view.addSubview(activitiesView)

        NSLayoutConstraint.activate([
            activitiesView.topAnchor.constraint(equalTo: view.topAnchor),
            activitiesView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            activitiesView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
        ])

        setupFilteringWithKeyword()
        configure(viewModel: viewModel)
    }

    deinit {
        activitiesView.resetStatefulStateToReleaseObjectToAvoidMemoryLeak()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.applyTintAdjustment()
        keyboardChecker.viewWillAppear()
        navigationItem.largeTitleDisplayMode = .never
        fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1()
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

    func didPressTransaction(transaction: TransactionInstance, in view: ActivitiesView) {
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
    }

}

extension ActivitiesViewController {

    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.dimsBackgroundDuringPresentation = false
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = Colors.headerThemeColor
    }

    private func setupFilteringWithKeyword() {
        //wireUpSearchController()
        doNotDimTableViewToReuseTableForFilteringResult()
        makeSwitchToAnotherTabWorkWhileFiltering()
    }

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true

        if let placeholderLabel = searchController.searchBar.firstSubview(ofType: UILabel.self) {
            placeholderLabel.textColor = Colors.lightGray
        }
        if let textField = searchController.searchBar.firstSubview(ofType: UITextField.self) {
            textField.textColor = Colors.appText
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Colors.appText
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchController.searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
        searchController.searchBar.backgroundColor = Colors.headerThemeColor
    }
}

extension ActivitiesViewController {
    class functional {}
}

extension ActivitiesViewController.functional {

    static func headerView(for section: Int, viewModel: ActivitiesViewModel) -> UIView {
        let container = UIView()
        container.backgroundColor = viewModel.headerBackgroundColor
        let title = UILabel()
        title.text = viewModel.titleForHeader(in: section)
        title.sizeToFit()
        title.textColor = viewModel.headerTitleTextColor
        title.font = viewModel.headerTitleFont
        container.addSubview(title)
        title.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            title.anchorsConstraint(to: container, edgeInsets: .init(top: 18, left: 20, bottom: 16, right: 0))
        ])
        return container
    }
}
