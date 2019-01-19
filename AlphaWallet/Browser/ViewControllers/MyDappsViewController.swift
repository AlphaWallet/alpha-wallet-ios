//
// Created by James Sangalli on 8/12/18.
//

import Foundation
import UIKit
import StatefulViewController

protocol MyDappsViewControllerDelegate: class {
    func didTapToEdit(dapp: Bookmark, inViewController viewController: MyDappsViewController)
    func didTapToSelect(dapp: Bookmark, inViewController viewController: MyDappsViewController)
    func delete(dapp: Bookmark, inViewController viewController: MyDappsViewController)
    func dismissKeyboard(inViewController viewController: MyDappsViewController)
}

class MyDappsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
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

        tableView.register(MyDappCell.self, forCellReuseIdentifier: MyDappCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableHeaderView = headerView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.allowsSelectionDuringEditing = true
        emptyView = {
            let emptyView = DappsHomeEmptyView()
            let headerViewModel = DappsHomeHeaderViewViewModel(title: R.string.localizable.myDappsButtonImageLabel())
            emptyView.configure(viewModel: .init(headerViewViewModel: headerViewModel, title: R.string.localizable.dappBrowserMyDappsEmpty()))
            return emptyView
        }()
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let keyboardBeginFrame = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            let keyboardHeight = keyboardEndFrame.size.height
            tableView.contentInset.bottom = keyboardEndFrame.size.height
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let keyboardBeginFrame = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
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
        let headerViewModel = DappsHomeHeaderViewViewModel(title: R.string.localizable.myDappsButtonImageLabel())
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
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MyDappCell.identifier, for: indexPath) as! MyDappCell
        let dapp = viewModel.dapp(atIndex: indexPath.row)
        cell.configure(viewModel: .init(dapp: dapp))
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.dappsCount
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
                    title: R.string.localizable.dappBrowserClearMyDapps(),
                    message: dapp.title,
                    okTitle: R.string.localizable.removeButtonTitle(),
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
