//
//  SwapOptionsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import AlphaWalletFoundation
import Combine
import StatefulViewController

protocol SwapOptionsViewControllerDelegate: AnyObject {
    func choseSwapToolSelected(in controller: SwapOptionsViewController)
    func didClose(in controller: SwapOptionsViewController)
}

class SwapOptionsViewController: UIViewController {
    private let viewModel: SwapOptionsViewModel

    private lazy var slippageView: SlippageView = {
        return SlippageView(viewModel: viewModel.slippageViewModel)
    }()

    private lazy var slippageHeaderView: SwapOptionsHeaderView = {
        let view = SwapOptionsHeaderView(viewModel: .init(title: "SLIPPAGE TOLERANCE"))
        return view
    }()

    private lazy var networkHeaderView: SwapOptionsHeaderView = {
        let view = SwapOptionsHeaderView(viewModel: .init(title: "Network"))
        return view
    }()

    private lazy var swapToolsHeaderView: SwapOptionsHeaderView = {
        let view = SwapOptionsHeaderView(viewModel: .init(title: "Preffered Exchanges"))
        let button = view.enableTapAction(title: R.string.localizable.editButtonTitle())
        button.addTarget(self, action: #selector(choseSwapToolSelected), for: .touchUpInside)

        return view
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView.selfSizingTableView
        tableView.register(RPCDisplaySelectableTableViewCell.self)
        tableView.delegate = self

        return tableView
    }()
    private lazy var swapToolsView: SelectedSwapToolsCollectionView = {
        return SelectedSwapToolsCollectionView(viewModel: viewModel.selectedSwapToolsViewModel, willAppear: willAppear.eraseToAnyPublisher())
    }()
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource: SwapOptionsViewModel.DataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<IndexPath, Never>()
    private let containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        view.stackView.spacing = 0

        return view
    }()

    weak var delegate: SwapOptionsViewControllerDelegate?

    init(viewModel: SwapOptionsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        containerView.stackView.addArrangedSubviews([
            .spacer(height: 20),
            slippageHeaderView.adjusted(),
            .spacer(height: 10),
            slippageView.adjusted(),
            .spacer(height: 30),
            swapToolsHeaderView.adjusted(),
            .spacer(height: 10),
            swapToolsView.adjusted(),
            .spacer(height: 10),
            networkHeaderView.adjusted(),
            .spacer(height: 10),
            tableView
        ])

        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.anchorsIgnoringBottomSafeArea(to: view)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem.logoBarButton()
        navigationItem.rightBarButtonItem = UIBarButtonItem.closeBarButton(self, selector: #selector(closeDidSelect))
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    } 

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func choseSwapToolSelected(_ sender: UIButton) {
        delegate?.choseSwapToolSelected(in: self)
    }

    @objc private func closeDidSelect(_ sender: UIButton) {
        delegate?.didClose(in: self)
    }

    private func bind(viewModel: SwapOptionsViewModel) {
        let output = viewModel.transform(input: .init(selection: selection.eraseToAnyPublisher()))
        output.viewState
            .sink { [weak dataSource, navigationItem] viewState in
                navigationItem.title = viewState.title
                dataSource?.apply(viewState.sessions, animatingDifferences: false)
            }.store(in: &cancelable)

        //TODO: need to resolve error displaying, uncommenting this string causes displaying an error when screen in loading for first time
        // and for unavailable networks it shows error
        //output.errorString
        //    .receive(on: RunLoop.main)
        //    .sink { [weak self] error in
        //        self?.displayError(message: error)
        //    }.store(in: &cancelable)
    }
}

extension SwapOptionsViewController {
    private func makeDataSource() -> SwapOptionsViewModel.DataSource {
        SwapOptionsViewModel.DataSource(tableView: tableView) { tableView, indexPath, viewModel -> RPCDisplaySelectableTableViewCell? in
            let cell: RPCDisplaySelectableTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}

extension SwapOptionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selection.send(indexPath)
    }

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

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }
}

private class SelfSizingTableView: UITableView {
    override var contentSize: CGSize {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let height = min(.infinity, contentSize.height)
        return CGSize(width: contentSize.width, height: height)
    }
}

extension UITableView {
    static var selfSizingTableView: UITableView {
        let tableView = SelfSizingTableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = Configuration.Color.Semantic.tableViewBackground
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.isEditing = false
        tableView.keyboardDismissMode = .onDrag
        tableView.separatorColor = Configuration.Color.Semantic.tableViewSeparator
        tableView.isScrollEnabled = false

        return tableView
    }
}
