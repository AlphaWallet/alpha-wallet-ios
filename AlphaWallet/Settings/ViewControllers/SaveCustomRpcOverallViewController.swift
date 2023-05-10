//
//  SaveCustomRpcOverallViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit
import AlphaWalletFoundation

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
            return R.string.localizable.customRPCOverallTabBrowse()
        case .manual:
            return R.string.localizable.customRPCOverallTabManual()
        }
    }

}

class SaveCustomRpcOverallViewController: UIViewController, SaveCustomRpcHandleUrlFailure {

    // MARK: - Properties
    // MARK: Private

    private let initalizeInitialFirstResponder: ExecuteOnceOnly = ExecuteOnceOnly()
    private let model: SaveCustomRpcOverallModel
    private var browseViewController: SaveCustomRpcBrowseViewController
    private var entryViewController: SaveCustomRpcManualEntryViewController
    private var selection: ControlSelection = .selected(UInt(SaveCustomRpcOverallTab.browse.position))

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

    override func loadView() {
        view = SaveCustomRpcOverallView(titles: [SaveCustomRpcOverallTab.browse.title, SaveCustomRpcOverallTab.manual.title])
    }

    // MARK: - Configuration

    private func configureViewController() {
        overallView.segmentedControl.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
        overallView.segmentedControl.setSelection(cellIndex: SaveCustomRpcOverallTab.browse.position)
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
        switch selection {
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

    // MARK: - ObjC handlers

    @objc func handleTap(_ sender: ScrollableSegmentedControl) {
        switch sender.selectedSegment {
        case .unselected:
            selection = .unselected
        case .selected(let index):
            selection = .selected(UInt(index))
        }
        activateCurrentViewController()
    }

}

// MARK: - Passthrough to manualViewController

extension SaveCustomRpcOverallViewController {

    func handleRpcUrlFailure() {
        entryViewController.handleRpcUrlFailure()
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

// MARK: - UITableViewDataSource

extension SaveCustomRpcBrowseDataController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return tableViewSection.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < tableViewSection.count else { return 0 }
        return tableViewSection[section].rows()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section < tableViewSection.count else { return UITableViewCell() }
        let cell: RPCDisplayTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let section = tableViewSection[indexPath.section]
        let server = section.serverAt(row: indexPath.row)
        let viewModel = ServerImageViewModel(server: .server(.custom(server)), isSelected: section.isMarked(chainID: server.chainID))
        cell.configure(viewModel: viewModel)
        return cell
    }

}

// MARK: - UITableViewDelegate

extension SaveCustomRpcBrowseDataController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < tableViewSection.count else { return }
        tableViewSection[indexPath.section].didSelect(row: indexPath.row)
        tableView.reloadRows(at: [indexPath], with: .automatic)
        configurationDelegate?.enableAddFunction(!selectedServers().isEmpty)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection sectionIndex: Int) -> UIView? {
        guard sectionIndex < tableViewSection.count else { return nil }
        return tableViewSection[sectionIndex].headerView()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section < tableViewSection.count else { return 0 }
        return tableViewSection[section].headerHeight()
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        80.0
    }

}

// MARK: - EnableServerHeaderViewDelegate

extension SaveCustomRpcBrowseDataController: EnableServersHeaderViewDelegate {

    func toggledTo(_ isEnabled: Bool, headerView: EnableServersHeaderView) {
        switch (headerView.mode, isEnabled) {
        case (.mainnet, true), (.testnet, false):
            switchToMainnet()
        case (.mainnet, false), (.testnet, true):
            switchToTestnet()
        }
        dataObserver?.dataHasChanged(rows: currentRowCount)
        configurationDelegate?.enableAddFunction(!selectedServers().isEmpty)
    }

    private func switchToMainnet() {
        mainnetTableViewSection?.enableSection()
        testnetTableViewSection?.disableSection()
    }

    private func switchToTestnet() {
        testnetTableViewSection?.enableSection()
        mainnetTableViewSection?.disableSection()
    }

}

