// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol DappsAutoCompletionViewControllerDelegate: class {
    func didTap(dapp: Dapp, inViewController viewController: DappsAutoCompletionViewController)
    func dismissKeyboard(inViewController viewController: DappsAutoCompletionViewController)
}

class DappsAutoCompletionViewController: UIViewController {
    private var viewModel: DappsAutoCompletionViewControllerViewModel
    private let tableView = UITableView(frame: .zero, style: .plain)
    weak var delegate: DappsAutoCompletionViewControllerDelegate?
    var text: String {
        return viewModel.keyword
    }

    init() {
        self.viewModel = .init()
        super.init(nibName: nil, bundle: nil)

        tableView.register(DappsAutoCompletionCell.self, forCellReuseIdentifier: DappsAutoCompletionCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
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
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
            tableView.contentInset.bottom = keyboardEndFrame.size.height
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        if let _ = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue, let _ = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
            tableView.contentInset.bottom = 0
        }
    }

    func filter(withText text: String) -> Bool {
        viewModel.keyword = text
        tableView.reloadData()
        return viewModel.dappSuggestionsCount > 0
    }
}

extension DappsAutoCompletionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DappsAutoCompletionCell.identifier, for: indexPath) as! DappsAutoCompletionCell
        let dapp = viewModel.dappSuggestions[indexPath.row]
        cell.configure(viewModel: .init(dapp: dapp, keyword: viewModel.keyword))
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.dappSuggestionsCount
    }
}

extension DappsAutoCompletionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.dismissKeyboard(inViewController: self)
        let dapp = viewModel.dappSuggestions[indexPath.row]
        delegate?.didTap(dapp: dapp, inViewController: self)
    }
}
