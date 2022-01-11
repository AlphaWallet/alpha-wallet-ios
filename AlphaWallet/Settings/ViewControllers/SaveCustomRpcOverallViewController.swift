//
//  SaveCustomRpcOverallViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit

enum SaveCustomRpcOverallTab {
    case browse
    case manual

    var position: Int {
        switch self {
        case .browse:
            return 0
        case .manual:
            return 1
        }
    }

    var title: String {
        switch self {
        case .browse:
            return R.string.localizable.customRPCOverallTabBrowse(preferredLanguages: Languages.preferred())
        case .manual:
            return R.string.localizable.customRPCOverallTabManual(preferredLanguages: Languages.preferred())
        }
    }

}

class SaveCustomRpcOverallViewController: UIViewController, SaveCustomRpcHandleUrlFailure {

    // MARK: - Properties
    // MARK: Private

    private let initalizeInitialFirstResponder: ExecuteOnceOnly = ExecuteOnceOnly()
    private let model: SaveCustomRpcOverallModel
    private var browseViewController: SaveCustomRpcBrowseViewController
    private var containerConstraints: [NSLayoutConstraint] = [NSLayoutConstraint]()
    private var entryViewController: SaveCustomRpcManualEntryViewController

    // MARK: Public

    var overallView: SaveCustomRpcOverallView {
        return view as! SaveCustomRpcOverallView
    }

    weak var browseDataDelegate: SaveCustomRpcBrowseViewControllerDataDelegate? {
        didSet {
            browseViewController.dataDelegate = browseDataDelegate
        }
    }

    weak var manualDataDelegate: SaveCustomRpcEntryViewControllerDataDelegate? {
        didSet {
            entryViewController.dataDelegate = manualDataDelegate
        }
    }

    // MARK: - UIElements

    // SearchContoller is located out here instead of in SaveCustomRpcOverallBrowseViewController because if you try setting the search controller there, you will not have the search controller in the correct place. Using UIPresentationController could fix this?

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.returnKeyType = .done
        searchController.searchBar.enablesReturnKeyAutomatically = false
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no
        searchController.searchBar.spellCheckingType = .no
        return searchController
    }()

    // MARK: - Constructors

    init(model: SaveCustomRpcOverallModel) {
        self.model = model
        let viewModel = SaveCustomRpcBrowseDataController(customRpcs: model.browseModel)
        browseViewController = SaveCustomRpcBrowseViewController(viewModel: viewModel)
        viewModel.dataObserver = browseViewController
        entryViewController = SaveCustomRpcManualEntryViewController(viewModel: SaveCustomRpcManualEntryViewModel(operation: model.manualOperation))
        super.init(nibName: nil, bundle: nil)
        viewModel.configurationDelegate = browseViewController
    }

    required init?(coder: NSCoder) {
        return nil
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewController()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerNotifications()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        deregisterNotifications()
    }

    override func loadView() {
        view = SaveCustomRpcOverallView(titles: [SaveCustomRpcOverallTab.browse.title, SaveCustomRpcOverallTab.manual.title])
    }

    // MARK: - Configuration

    private func configureViewController() {
        overallView.delegate = self
        browseViewController.searchDelegate = self
        searchController.searchResultsUpdater = browseViewController
        searchController.delegate = self
        definesPresentationContext = true
        modalPresentationStyle = .overCurrentContext
        add(childViewController: browseViewController)
        add(childViewController: entryViewController)
        activateCurrentViewController()
    }

    private func activateCurrentViewController() {
        switch overallView.segmentedControl.selection {
        case .selected(let tab) where tab == SaveCustomRpcOverallTab.browse.position:
            activateBrowseViewController()
        case .selected(let tab) where tab == SaveCustomRpcOverallTab.manual.position:
            activateManualViewController()
        default: // Impossible to get here but we set to browse so there is a defined state
            activateBrowseViewController()
        }
    }

    private func activateBrowseViewController() {
        entryViewController.view.isHidden = true
        browseViewController.view.isHidden = false
        // navigationItem.rightBarButtonItem = addButton
        view.endEditing(true)
    }

    private func activateManualViewController() {
        entryViewController.view.isHidden = false
        browseViewController.view.isHidden = true
        initalizeInitialFirstResponder.once {
            DispatchQueue.main.async { self.entryViewController.editView.chainNameTextField.becomeFirstResponder() }
        }
        hideSearchBar()
    }

    // MARK: - Notifications

    private func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow(_:)), name: UIWindow.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide(_:)), name: UIWindow.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillChangeFrame(_:)), name: UIWindow.keyboardWillChangeFrameNotification, object: nil)
    }

    private func deregisterNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIWindow.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIWindow.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIWindow.keyboardWillChangeFrameNotification, object: nil)
    }

    // MARK: Child View Controllers

    private func add(childViewController: UIViewController) {
        addChild(childViewController)
        overallView.addSubview(childViewController.view)
        NSLayoutConstraint.activate([
            childViewController.view.topAnchor.constraint(equalTo: overallView.containerView.topAnchor),
            childViewController.view.leadingAnchor.constraint(equalTo: overallView.containerView.leadingAnchor),
            childViewController.view.trailingAnchor.constraint(equalTo: overallView.containerView.trailingAnchor),
            childViewController.view.bottomAnchor.constraint(equalTo: overallView.containerView.bottomAnchor)
        ])
        childViewController.didMove(toParent: self)
    }

    // MARK: - Objc handlers

    @objc private func handleKeyboardWillShow(_ notification: Notification) {
        guard let frame = getCGRectFromNotification(notification) else { return }
        animateKeyboardChange(frame.height)
    }

    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        animateKeyboardChange(0)
    }

    @objc private func handleKeyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = getCGRectFromNotification(notification) else { return }
        animateKeyboardChange(frame.height)
    }

    private func animateKeyboardChange(_ frameHeight: CGFloat) {
        // TODO: - Maybe use UIEdgeInsets instead of a constraint?
        guard let bottomConstraint = overallView.bottomConstraint else { return }
        let animation = UIViewPropertyAnimator(duration: Style.Animation.duration, curve: Style.Animation.curve) {
            bottomConstraint.constant = -frameHeight
            self.view.layoutIfNeeded()
        }
        animation.startAnimation()
    }

    // MARK: - Public functions

    // MARK: - Utility

    private func getCGRectFromNotification(_ notification: Notification) -> CGRect? {
        guard let userInfo = notification.userInfo, let value = userInfo[UIWindow.keyboardFrameEndUserInfoKey] as? NSValue else { return nil }
        return value.cgRectValue
    }

    // MARK: - Search Bar

    func showSearchBar() {
        let animation = UIViewPropertyAnimator(duration: Style.Animation.duration, curve: Style.Animation.curve) {
            self.navigationItem.searchController = self.searchController
            self.browseViewController.hideSearchBar()
            self.view.layoutIfNeeded()
        }
        animation.addCompletion { _ in
            self.searchController.searchBar.becomeFirstResponder()
        }
        animation.startAnimation()
    }

    func hideSearchBar() {
        UIViewPropertyAnimator(duration: Style.Animation.duration, curve: Style.Animation.curve) {
            self.navigationItem.searchController = nil
            self.browseViewController.showSearchBar()
            self.view.layoutIfNeeded()
        }.startAnimation()
    }

}

// MARK: - Passthrough to manualViewController

extension SaveCustomRpcOverallViewController {

    func handleRpcUrlFailure() {
        entryViewController.handleRpcUrlFailure()
    }

}

// MARK: - SegmentedControlDelegate

extension SaveCustomRpcOverallViewController: SegmentedControlDelegate {

    func didTapSegment(atSelection selection: SegmentedControl.Selection, inSegmentedControl segmentedControl: SegmentedControl) {
        guard segmentedControl.selection != selection else { return }
        segmentedControl.selection = selection
        activateCurrentViewController()
    }

}

// MARK: - SaveCustomRpcBrowseViewControllerDelegate

extension SaveCustomRpcOverallViewController: SaveCustomRpcBrowseViewControllerSearchDelegate {

    func showSearchController() {
        showSearchBar()
    }

}

// MARK: - UISearchControllerDelegate

extension SaveCustomRpcOverallViewController: UISearchControllerDelegate {

    func didDismissSearchController(_ searchController: UISearchController) {
        hideSearchBar()
    }

}

extension SaveCustomRpcOverallViewController: HandleAddMultipleCustomRpcViewControllerResponse {

    func handleAddMultipleCustomRpcFailure(added: NSArray, failed: NSArray, duplicates: NSArray, remaining: NSArray) {
        browseViewController.handleAddMultipleCustomRpcFailure(added: added, failed: failed, duplicates: duplicates, remaining: remaining)
    }

}
