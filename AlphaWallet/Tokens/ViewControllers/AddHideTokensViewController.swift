// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import StatefulViewController
import PromiseKit

protocol AddHideTokensViewControllerDelegate: AnyObject {
    func didPressAddToken(in viewController: UIViewController)
    func didMark(token: TokenObject, in viewController: UIViewController, isHidden: Bool)
    func didChangeOrder(tokens: [TokenObject], in viewController: UIViewController)
    func didClose(viewController: AddHideTokensViewController)
}

class AddHideTokensViewController: UIViewController {
     
    enum AddHideToken {
        case insert
        case delete
    }
    
    private let assetDefinitionStore: AssetDefinitionStore
    private var viewModel: AddHideTokensViewModel
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(WalletTokenViewCell.self)
        tableView.register(PopularTokenViewCell.self)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var searchField: UITextField = {
        let tf = UITextField(frame: .zero)
        tf.cornerRadius = 5
        tf.borderWidth = 2
        tf.borderColor = Colors.borderGrayColor
        
        let img = UIImageView(image: R.image.search())
        let vw = UIView(frame: .init(origin: .zero, size: .init(width: 50, height: 40)))
        vw.addSubview(img)
        img.center = vw.center
        tf.leftView = vw
        tf.leftViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.attributedPlaceholder = NSAttributedString(
            string: "Search for Tokens...",
            attributes: [NSAttributedString.Key.foregroundColor: Colors.borderGrayColor]
        )
        tf.delegate = self
        return tf
    }()
    
    private let refreshControl = UIRefreshControl()

    private var bottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)
    weak var delegate: AddHideTokensViewControllerDelegate?

    init(viewModel: AddHideTokensViewModel, assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        emptyView = EmptyView.filterTokensEmptyView(completion: { [weak self] in
            guard let strongSelf = self, let delegate = strongSelf.delegate else { return }

            delegate.didPressAddToken(in: strongSelf)
        }) 

        view.addSubview(searchField)
        view.addSubview(tableView)

        bottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        keyboardChecker.constraint = bottomConstraint

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            searchField.heightAnchor.constraint(equalToConstant: 40),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 20),
            
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)
        setupFilteringWithKeyword()

        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem.addButton(self, selector: #selector(addToken))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardChecker.viewWillAppear()
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()

        if isMovingFromParent || isBeingDismissed {
            delegate?.didClose(viewController: self)
            return
        }
    }

    override func viewDidLayoutSubviews() {
    }

    @objc private func addToken() {
        delegate?.didPressAddToken(in: self)
    }

    private func configure(viewModel: AddHideTokensViewModel) {
        title = viewModel.title
        tableView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
    }

    private func reload() {
        startLoading(animated: false)
        tableView.reloadData()
        endLoading(animated: false)
    }

    func add(token: TokenObject) {
        viewModel.add(token: token)
        reload()
    }

    func set(popularTokens: [PopularToken]) {
        viewModel.set(allPopularTokens: popularTokens)

        DispatchQueue.main.async {
            self.reload()
        }
    }
}

extension AddHideTokensViewController: StatefulViewController {
    //Always return true, otherwise users will be stuck in the assets sub-tab when they have no assets
    func hasContent() -> Bool {
        return !viewModel.sections.isEmpty
    }
}

extension AddHideTokensViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfItems(section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let token = viewModel.item(atIndexPath: indexPath) else { return UITableViewCell() }
        let isVisible = viewModel.displayedToken(indexPath: indexPath)

        switch token {
        case .walletToken(let tokenObject):
            let cell: WalletTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: tokenObject, assetDefinitionStore: assetDefinitionStore, isVisible: isVisible))
            cell.delegate = self
            return cell
        case .popularToken(let value):
            let cell: PopularTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(token: value, isVisible: isVisible))
            cell.delegate = self
            return cell
        }
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if let tokens = viewModel.moveItem(from: sourceIndexPath, to: destinationIndexPath) {
            delegate?.didChangeOrder(tokens: tokens, in: self)
        }
        reload()
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        viewModel.canMoveItem(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let result: AddHideTokensViewModel.ShowHideOperationResult
        let isTokenHidden: Bool

        switch editingStyle {
        case .insert:
            result = viewModel.addDisplayed(indexPath: indexPath)
            isTokenHidden = false
        case .delete:
            result = viewModel.deleteToken(indexPath: indexPath)
            isTokenHidden = true
        case .none:
            result = .value(nil)
            isTokenHidden = false
        }

        switch result {
        case .value(let result):
            if let result = result, let delegate = delegate {
                delegate.didMark(token: result.token, in: self, isHidden: isTokenHidden)
                tableView.performBatchUpdates({
                    tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }, completion: nil)
            } else {
                tableView.reloadData()
            }
        case .promise(let promise):
            self.displayLoading()
            promise.done(on: .none, flags: .barrier) { [weak self] result in
                guard let strongSelf = self else { return }

                if let result = result, let delegate = strongSelf.delegate {
                    delegate.didMark(token: result.token, in: strongSelf, isHidden: isTokenHidden)
                }
            }.catch { _ in
                self.displayError(message: R.string.localizable.walletsHideTokenErrorAddTokenFailure())
            }.finally {
                tableView.reloadData()

                self.hideLoading()
            }
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.walletsHideTokenTitle()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] _, _, completionHandler in
            guard let strongSelf = self else { return }

            switch strongSelf.viewModel.deleteToken(indexPath: indexPath) {
            case .value(let result):
                if let result = result, let delegate = strongSelf.delegate {
                    delegate.didMark(token: result.token, in: strongSelf, isHidden: true)

                    tableView.performBatchUpdates({
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                        tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
                    }, completion: nil)

                    completionHandler(true)
                } else {
                    tableView.reloadData()

                    completionHandler(false)
                }
            case .promise:
                break
            }
        }

        hideAction.backgroundColor = R.color.danger()
        hideAction.image = R.image.hideToken()

        let configuration = UISwipeActionsConfiguration(actions: [hideAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }
}

extension AddHideTokensViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        viewModel.editingStyle(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if sourceIndexPath.section != proposedDestinationIndexPath.section {
            var row = 0
            if sourceIndexPath.section < proposedDestinationIndexPath.section {
                row = self.tableView(tableView, numberOfRowsInSection: sourceIndexPath.section) - 1
            }
            return IndexPath(row: row, section: sourceIndexPath.section)
        }
        return proposedDestinationIndexPath
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.sections[section] {
        case .availableNewTokens, .popularTokens, .hiddenTokens, .displayedTokens:
            let viewModel: AddHideTokenSectionHeaderViewModel = .init(titleText: self.viewModel.titleForSection(section))
            return AddHideTokensViewController.functional.headerView(for: section, viewModel: viewModel)
        case .sortingFilters:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}

///Support searching/filtering tokens with keywords. This extension is set up so it's easier to copy and paste this functionality elsewhere
extension AddHideTokensViewController {
    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func fixTableViewBackgroundColor() {
        let v = UIView()
        v.backgroundColor = viewModel.backgroundColor
        tableView.backgroundView = v
        view.backgroundColor = viewModel.backgroundColor
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = viewModel.backgroundColor
    }

    private func setupFilteringWithKeyword() {
        fixTableViewBackgroundColor()
        makeSwitchToAnotherTabWorkWhileFiltering()
    }
}

extension AddHideTokensViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let textFieldText: NSString = (textField.text ?? "") as NSString
        let txtAfterUpdate = textFieldText.replacingCharacters(in: range, with: string)
        
        self.viewModel.searchText = txtAfterUpdate
        self.reload()
        return true
    }
}

extension AddHideTokensViewController: PopularTokenViewCellDelegate {
    func cell(_ cell: PopularTokenViewCell, switchStateChanged isOn: Bool) {
        guard let indexPath = cell.indexPath else { return }
        if isOn {
            self.addHideToken(editingStyle: .insert, indexPath: indexPath)
        } else {
            self.addHideToken(editingStyle: .delete, indexPath: indexPath)
        }
    }
}

extension AddHideTokensViewController: WalletTokenViewCellDelegate {
    func cell(_ cell: WalletTokenViewCell, switchStateChanged isOn: Bool) {
        guard let indexPath = cell.indexPath else { return }
        if isOn {
            self.addHideToken(editingStyle: .insert, indexPath: indexPath)
        } else {
            self.addHideToken(editingStyle: .delete, indexPath: indexPath)
        }
    }
    
    func addHideToken(editingStyle: AddHideToken, indexPath: IndexPath) {
        let result: AddHideTokensViewModel.ShowHideOperationResult
        let isTokenHidden: Bool
        switch editingStyle {
        case .insert:
            result = viewModel.addDisplayed(indexPath: indexPath)
            isTokenHidden = false
        case .delete:
            result = viewModel.deleteToken(indexPath: indexPath)
            isTokenHidden = true
        }

        switch result {
        case .value(let result):
            if let result = result, let delegate = delegate {
                delegate.didMark(token: result.token, in: self, isHidden: isTokenHidden)
                tableView.performBatchUpdates({
                    tableView.insertRows(at: [result.indexPathToInsert], with: .automatic)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }, completion: nil)
            } else {
                tableView.reloadData()
            }
        case .promise(let promise):
            self.displayLoading()
            promise.done(on: .none, flags: .barrier) { [weak self] result in
                guard let strongSelf = self else { return }

                if let result = result, let delegate = strongSelf.delegate {
                    delegate.didMark(token: result.token, in: strongSelf, isHidden: isTokenHidden)
                }
            }.catch { _ in
                self.displayError(message: R.string.localizable.walletsHideTokenErrorAddTokenFailure())
            }.finally {
                self.tableView.reloadData()
                self.hideLoading()
            }
        }
    }
    
}
