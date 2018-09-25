// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import UIKit

protocol MasterBrowserViewControllerDelegate: class {
    func didPressAction(_ action: BrowserToolbarAction)
}

enum BrowserToolbarAction {
    case view(BookmarksViewType)
    case qrCode
}

enum BookmarksViewType: Int {
    case browser
    case bookmarks
    case history
}

final class MasterBrowserViewController: UIViewController {

    private lazy var segmentController: UISegmentedControl = {
        let items = [
            R.string.localizable.new(),
            R.string.localizable.bookmarks(),
            R.string.localizable.history(),
        ]
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.addTarget(self, action: #selector(selectionDidChange(_:)), for: .valueChanged)
        segmentedControl.style()
        return segmentedControl
    }()

    private lazy var qrcodeButton: UIButton = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(R.image.browser_scan()?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.imageView?.tintColor = Colors.appBackground
        button.addTarget(self, action: #selector(qrReader), for: .touchUpInside)
        return button
    }()

    weak var delegate: MasterBrowserViewControllerDelegate?

    let bookmarksViewController: BookmarkViewController
    let historyViewController: HistoryViewController
    let browserViewController: BrowserViewController

    init(
        bookmarksViewController: BookmarkViewController,
        historyViewController: HistoryViewController,
        browserViewController: BrowserViewController,
        type: BookmarksViewType
    ) {
        self.bookmarksViewController = bookmarksViewController
        self.historyViewController = historyViewController
        self.browserViewController = browserViewController
        super.init(nibName: nil, bundle: nil)

        segmentController.selectedSegmentIndex = type.rawValue
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController = navigationController, navigationController.isBeingPresented {
            browserViewController.setUpCloseButtonAs(hidden: false)
        } else if isBeingPresented {
            browserViewController.setUpCloseButtonAs(hidden: false)
        } else {
            browserViewController.setUpCloseButtonAs(hidden: true)
        }
    }

    func select(viewType: BookmarksViewType) {
        segmentController.selectedSegmentIndex = viewType.rawValue
        updateView()
    }

    private func setupView() {
        let items: [UIBarButtonItem] = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
            UIBarButtonItem(customView: segmentController),
            UIBarButtonItem(customView: qrcodeButton),
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil),
        ]
        toolbarItems = items
        navigationController?.isToolbarHidden = false
        navigationController?.toolbar.isTranslucent = false
        updateView()
    }

    private func updateView() {
        if segmentController.selectedSegmentIndex == BookmarksViewType.bookmarks.rawValue {
            remove(asChildViewController: browserViewController)
            remove(asChildViewController: historyViewController)
            add(asChildViewController: bookmarksViewController)
        } else if segmentController.selectedSegmentIndex == BookmarksViewType.history.rawValue {
            remove(asChildViewController: browserViewController)
            remove(asChildViewController: bookmarksViewController)
            add(asChildViewController: historyViewController)
        } else {
            remove(asChildViewController: bookmarksViewController)
            remove(asChildViewController: historyViewController)
            add(asChildViewController: browserViewController)
        }
    }

    @objc func selectionDidChange(_ sender: UISegmentedControl) {
        updateView()

        guard let viewType = BookmarksViewType(rawValue: sender.selectedSegmentIndex) else {
            return
        }
        delegate?.didPressAction(.view(viewType))
    }

    @objc func qrReader() {
        delegate?.didPressAction(.qrCode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MasterBrowserViewController: Scrollable {
    func scrollOnTop() {
        browserViewController.goHome()
    }
}
