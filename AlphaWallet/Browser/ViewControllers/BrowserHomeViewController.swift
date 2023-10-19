//
// Created by James Sangalli on 8/12/18.
//

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

protocol BrowserHomeViewControllerDelegate: AnyObject {
    func didTapShowMyDappsViewController(in viewController: BrowserHomeViewController)
    func didTapShowBrowserHistoryViewController(in viewController: BrowserHomeViewController)
    func didTap(bookmark: BookmarkObject, in viewController: BrowserHomeViewController)
    func viewWillAppear(in viewController: BrowserHomeViewController)
    func dismissKeyboard(in viewController: BrowserHomeViewController)
}

class BrowserHomeViewController: UIViewController {
    private var isEditingDapps = false {
        didSet {
            dismissKeyboard()
            if isEditingDapps {
                if !oldValue {
                    let vibration = UIImpactFeedbackGenerator()
                    vibration.prepare()
                    vibration.impactOccurred()
                }
                //TODO should this be a state case in the nav bar, but with a flag (associated value?) whether to disable the buttons?
                browserNavBar?.disableButtons()
                guard timerToCheckIfStillEditing == nil else { return }

                timerToCheckIfStillEditing = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let strongSelf = self else { return }
                    if strongSelf.isTopViewController {
                    } else {
                        strongSelf.isEditingDapps = false
                    }
                }
            } else {
                //TODO should this be a state case in the nav bar, but with a flag (associated value?) whether to disable the buttons?
                browserNavBar?.enableButtons()

                timerToCheckIfStillEditing?.invalidate()
                timerToCheckIfStillEditing = nil
            }
            collectionView.reloadData()
        }
    }
    private var timerToCheckIfStillEditing: Timer?
    private let viewModel: BrowserHomeViewModel
    private var browserNavBar: DappBrowserNavigationBar? {
        return navigationController?.navigationBar as? DappBrowserNavigationBar
    }
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let fixedGutter = CGFloat(24)
        let availableWidth = UIScreen.main.bounds.size.width - (2 * fixedGutter)
        let numberOfColumns: CGFloat
        if ScreenChecker().isBigScreen {
            numberOfColumns = 6
        } else {
            numberOfColumns = 3
        }
        let dimension = (availableWidth / numberOfColumns).rounded(.down)
        //Using a sizing cell doesn't get the same reason after we change network. Resorting to hardcoding the width and height difference
        let itemSize = CGSize(width: dimension, height: dimension + 30)
        let additionalGutter = (availableWidth - itemSize.width * numberOfColumns) / (numberOfColumns + 1)
        layout.itemSize = itemSize
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = .init(top: 0, left: additionalGutter + fixedGutter, bottom: 0, right: additionalGutter + fixedGutter)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.alwaysBounceVertical = true
        collectionView.registerSupplementaryView(DappsHomeViewControllerHeaderView.self, of: UICollectionView.elementKindSectionHeader)
        collectionView.register(DappViewCell.self)
        collectionView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        collectionView.delegate = self

        return collectionView
    }()

    private lazy var dataSource = makeDataSource()
    private var cancelable = Set<AnyCancellable>()
    private let deleteBookmark = PassthroughSubject<BookmarkObject, Never>()

    weak var delegate: BrowserHomeViewControllerDelegate?

    init(viewModel: BrowserHomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.anchorsConstraint(to: view)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        delegate?.viewWillAppear(in: self)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
            collectionView.contentInset.bottom = keyboardEndFrame.size.height
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        if let _ = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue, let _ = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
            collectionView.contentInset.bottom = 0
        }
    }

    private func bind(viewModel: BrowserHomeViewModel) {
        let input = DappsHomeViewViewModelInput(deleteBookmark: deleteBookmark.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource] viewState in
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
            }.store(in: &cancelable)
    }

    @objc private func showMyDappsViewController() {
        dismissKeyboard()
        delegate?.didTapShowMyDappsViewController(in: self)
    }

    @objc private func showBrowserHistoryViewController() {
        dismissKeyboard()
        delegate?.didTapShowBrowserHistoryViewController(in: self)
    }

    private func dismissKeyboard() {
        delegate?.dismissKeyboard(in: self)
    }
}

extension BrowserHomeViewController: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        dismissKeyboard()

        delegate?.didTap(bookmark: dataSource.item(at: indexPath).bookmark, in: self)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let headerView = DappsHomeViewControllerHeaderView()
        headerView.configure()
        return headerView.systemLayoutSizeFitting(.init(width: collectionView.frame.size.width, height: 1000))
    }
}

fileprivate extension BrowserHomeViewController {

    func makeDataSource() -> BrowserHomeViewModel.DataSource {
        let dataSource = BrowserHomeViewModel.DataSource(collectionView: collectionView, cellProvider: { [weak self] collectionView, indexPath, viewModel in
            guard let strongSelf = self else { return UICollectionViewCell() }

            let cell: DappViewCell = collectionView.dequeueReusableCell(for: indexPath)

            cell.delegate = strongSelf
            cell.configure(viewModel: viewModel)
            cell.isEditing = strongSelf.isEditingDapps

            return cell
        })

        dataSource.supplementaryViewProvider = { [weak self] collectionView, elementKind, indexPath in
            guard let strongSelf = self else { return nil }

            let headerView: DappsHomeViewControllerHeaderView = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, for: indexPath)
            headerView.delegate = strongSelf
            headerView.configure(viewModel: .init(isEditing: strongSelf.isEditingDapps))
            headerView.myDappsButton.addTarget(strongSelf, action: #selector(strongSelf.showMyDappsViewController), for: .touchUpInside)
            headerView.historyButton.addTarget(strongSelf, action: #selector(strongSelf.showBrowserHistoryViewController), for: .touchUpInside)

            return headerView
        }

        return dataSource
    }
}

extension BrowserHomeViewController: DappViewCellDelegate {
    func didTapDelete(in cell: DappViewCell) {
        guard let indexPath = cell.indexPath else { return }

        let cell = dataSource.item(at: indexPath)

        Task { @MainActor in
            guard case .success = await confirm(
                title: R.string.localizable.dappBrowserClearMyDapps(),
                message: cell.title,
                okTitle: R.string.localizable.removeButtonTitle(),
                okStyle: .destructive) else { return }

            deleteBookmark.send(cell.bookmark)
        }
    }

    func didLongPressed(in cell: DappViewCell) {
        isEditingDapps = true
    }
}

extension BrowserHomeViewController: DappsHomeViewControllerHeaderViewDelegate {
    func didExitEditMode(inHeaderView: DappsHomeViewControllerHeaderView) {
        isEditingDapps = false
    }
}
