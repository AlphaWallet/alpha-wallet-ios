//
// Created by James Sangalli on 8/12/18.
//

import Foundation
import UIKit
import StatefulViewController

protocol MyDappsViewControllerDelegate: AnyObject {
    func didTapToEdit(dapp: Bookmark, inViewController viewController: MyDappsViewController)
    func didTapToSelect(dapp: Bookmark, inViewController viewController: MyDappsViewController)
    func delete(dapp: Bookmark, inViewController viewController: MyDappsViewController)
    func dismissKeyboard(inViewController viewController: MyDappsViewController)
    func didReorderDapps(inViewController viewController: MyDappsViewController)
}

class MyDappsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    lazy private var headerView = MyDappsViewControllerHeaderView()
    private var viewModel: MyDappsViewControllerViewModel
    private var browserNavBar: DappBrowserNavigationBar? {
        return navigationController?.navigationBar as? DappBrowserNavigationBar
    }
    private let bookmarksStore: BookmarksStore

    weak var delegate: MyDappsViewControllerDelegate?

    init(bookmarksStore: BookmarksStore) {
        self.bookmarksStore = bookmarksStore
        self.viewModel = .init(bookmarksStore: bookmarksStore)
        super.init(nibName: nil, bundle: nil)

        tableView.register(MyDappCell.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableHeaderView = headerView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsSelectionDuringEditing = true
        emptyView = {
            let emptyView = DappsHomeEmptyView()
            let headerViewModel = DappsHomeHeaderViewViewModel(title: R.string.localizable.myDappsButtonImageLabel(preferredLanguages: Languages.preferred()))
            emptyView.configure(viewModel: .init(headerViewViewModel: headerViewModel, title: R.string.localizable.dappBrowserMyDappsEmpty(preferredLanguages: Languages.preferred())))
            return emptyView
        }()
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset.bottom = keyboardEndFrame.size.height
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        if let _ = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset.bottom = 0
        }
    }

    func configure(viewModel: MyDappsViewControllerViewModel) {
        self.viewModel = viewModel

        tableView.backgroundColor = Colors.appWhite

        resizeTableViewHeader()
        tableView.reloadData()
        endLoading()
    }

    private func resizeTableViewHeader() {
        headerView.delegate = self
        let headerViewModel = DappsHomeHeaderViewViewModel(title: R.string.localizable.myDappsButtonImageLabel(preferredLanguages: Languages.preferred()))
        headerView.configure(viewModel: headerViewModel)
        headerView.backgroundColor = headerViewModel.backgroundColor
        let fittingSize = headerView.systemLayoutSizeFitting(.init(width: tableView.frame.size.width, height: 1000))
        headerView.frame = .init(x: 0, y: 0, width: 0, height: fittingSize.height)
        tableView.tableHeaderView = headerView
    }

    private func dismissKeyboard() {
        delegate?.dismissKeyboard(inViewController: self)
    }
}

extension MyDappsViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.hasContent
    }
}

extension MyDappsViewController: UITableViewDataSource {
    //Hide the header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: MyDappCell = tableView.dequeueReusableCell(for: indexPath)
        let dapp = viewModel.dapp(atIndex: indexPath.row)
        cell.configure(viewModel: .init(dapp: dapp))
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.dappsCount
    }

    public func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        bookmarksStore.moveBookmark(fromIndex: sourceIndexPath.row, toIndex: destinationIndexPath.row)
        delegate?.didReorderDapps(inViewController: self)
    }
}

extension MyDappsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let dapp = viewModel.dapp(atIndex: indexPath.row)
        if tableView.isEditing {
            delegate?.didTapToEdit(dapp: dapp, inViewController: self)
        } else {
            dismissKeyboard()
            delegate?.didTapToSelect(dapp: dapp, inViewController: self)
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let dapp = viewModel.dapp(atIndex: indexPath.row)
            confirm(
                    title: R.string.localizable.dappBrowserClearMyDapps(preferredLanguages: Languages.preferred()),
                    message: dapp.title,
                    okTitle: R.string.localizable.removeButtonTitle(preferredLanguages: Languages.preferred()),
                    okStyle: .destructive
            ) { [weak self] result in
                switch result {
                case .success:
                    guard let strongSelf = self else { return }
                    strongSelf.delegate?.delete(dapp: dapp, inViewController: strongSelf)
                    if !strongSelf.viewModel.hasContent {
                        strongSelf.headerView.exitEditMode()
                    }
                case .failure:
                    break
                }
            }
        }
    }
}

extension MyDappsViewController: MyDappsViewControllerHeaderViewDelegate {
    func didEnterEditMode(inHeaderView headerView: MyDappsViewControllerHeaderView) {
        //TODO should this be a state case in the nav bar, but with a flag (associated value?) whether to disable the buttons?
        browserNavBar?.disableButtons()
        tableView.setEditing(true, animated: true)
    }

    func didExitEditMode(inHeaderView headerView: MyDappsViewControllerHeaderView) {
        //TODO should this be a state case in the nav bar, but with a flag (associated value?) whether to disable the buttons?
        browserNavBar?.enableButtons()
        tableView.setEditing(false, animated: true)
    }
}
