// Copyright © 2020 Stormbird PTE. LTD.

import BigInt
import Foundation
import UIKit
import Result

class ConfirmTransactionViewController: UIViewController, UpdatablePreferredContentSize {

    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var viewModel: ConfirmTransactionViewModel

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.registerHeaderFooterView(ConfirmTransactionTableViewHeader.self)
        tableView.separatorStyle = .none

        return tableView
    }()

    private let separatorLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()

        return view
    }()

    private var contentSizeObservation: NSKeyValueObservation!
    private let footerHeight: CGFloat = 120
    private let separatorHeight: CGFloat = 1.0
    private var contentSize: CGSize {
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let contentHeight = tableView.contentSize.height + footerHeight + separatorHeight
        let height = min(UIScreen.main.bounds.height - statusBarHeight, contentHeight)
        return CGSize(width: UIScreen.main.bounds.width, height: height)
    }

    //NOTE: we are using flag to disable animation until first UITableView open/hide action
    var updatePreferredContentSizeAnimated: Bool = false
    var didCompleted: (() -> Void)?

    init(viewModel: ConfirmTransactionViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        tableView.backgroundColor = viewModel.backgroundColor
        view.backgroundColor = viewModel.backgroundColor
        navigationItem.title = viewModel.title
        view.addSubview(tableView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = viewModel.backgroundColor
        view.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        view.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: separatorLine.topAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor, constant: 20),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            separatorLine.heightAnchor.constraint(equalToConstant: separatorHeight),
            separatorLine.bottomAnchor.constraint(equalTo: footerBar.topAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: footerHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        title = viewModel.navigationTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem.appIconBarButton
        navigationItem.rightBarButtonItem = UIBarButtonItem.closeBarButton(self, selector: #selector(dismissViewController))

        //NOTE: we observe UITableView.contentSize to determine view controller height.
        //we are using Throttler because during UITableViewUpdate procces contentSize changes with range of values, so we need latest valid value.
        let limitter = RateLimiter(limit: 0.05) { [weak self] in
            guard let strongSelf = self, let controller = strongSelf.navigationController else { return }
            controller.preferredContentSize = strongSelf.contentSize
        }

        contentSizeObservation = tableView.observe(\.contentSize, options: [.new, .initial]) { _, _ in
            limitter.run()
        }
    }

    deinit {
        contentSizeObservation.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure(for: viewModel)
    }

    @objc private func dismissViewController() {
        dismiss(animated: true)
    }

    private func configure(for detailsViewModel: ConfirmTransactionViewModel) {
        buttonsBar.configure()
        let button = buttonsBar.buttons[0]
        button.setTitle(viewModel.confirmButtonTitle, for: .normal)
        button.addTarget(self, action: #selector(confirmButtonSelected), for: .touchUpInside)

        tableView.reloadData()
    }

    @objc func confirmButtonSelected(_ sender: UIButton) {
        dismiss(animated: true, completion: didCompleted)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension ConfirmTransactionViewController: UITableViewDelegate {

}

extension ConfirmTransactionViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header: ConfirmTransactionTableViewHeader = tableView.dequeueReusableHeaderFooterView()
        header.configure(viewModel: viewModel.viewModel(section: section))

        return header
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }
}

private extension UIBarButtonItem {

    static var appIconBarButton: UIBarButtonItem {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFit
        view.image = R.image.awLogoSmall()
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true

        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.anchorsConstraint(to: container)
        ])

        return UIBarButtonItem(customView: container)
    }

    static func closeBarButton(_ target: AnyObject, selector: Selector) -> UIBarButtonItem {
        return .init(image: R.image.close(), style: .plain, target: target, action: selector)
    }
}
