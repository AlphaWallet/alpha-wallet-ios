//
//  InitialNetworkSelectionView.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/5/22.
//

import UIKit

typealias InitialNetworkSelectionViewResultsCallback = (Int) -> Void

class InitialNetworkSelectionView: UIView {

    // MARK: - Accessors

    var tableViewDelegate: UITableViewDelegate? {
        get {
            tableView.delegate
        }
        set (newValue) {
            tableView.delegate = newValue
        }
    }

    var tableViewDataSource: UITableViewDataSource? {
        get {
            tableView.dataSource
        }
        set (newValue) {
            tableView.dataSource = newValue
        }
    }

    var searchBarDelegate: UISearchBarDelegate? {
        get {
            searchBar.delegate
        }
        set (newValue) {
            searchBar.delegate = newValue
        }
    }

    var continueButton: UIButton {
        return buttonsBar.buttons[0]
    }

    // MARK: - Vars (Private)

    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = Configuration.Color.Semantic.tableViewBackground
        tableView.isEditing = false
        return tableView
    }()

    private let emptyTableView: EmptyTableView = {
        let view = EmptyTableView(title: R.string.localizable.emptyTableViewSearchTitle(), image: R.image.iconsIllustrationsSearchResults()!, heightAdjustment: 100)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private lazy var buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()
        return buttonsBar
    }()

    // MARK: - Initializers

    init() {
        super.init(frame: .zero)
        constructView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(viewModel: InitialNetworkSelectionViewModel) {
        viewModel.register(tableView)
    }

    // MARK: - Constructors (Private)

    private func constructView() {
        addSubview(searchBar)
        addSubview(tableView)
        addSubview(buttonsBar)
        addSubview(emptyTableView)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8.0),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: buttonsBar.topAnchor, constant: -8.0),

            buttonsBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20.0),
            buttonsBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20.0),
            buttonsBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            emptyTableView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyTableView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
        ])
        UIKitFactory.decorateAsDefaultView(self)
    }

    // MARK: - public functions

    func reloadTableView() {
        tableView.reloadData()
    }

    func setTableViewEmpty(isHidden: Bool) {
        emptyTableView.isHidden = !isHidden
    }
    
}
