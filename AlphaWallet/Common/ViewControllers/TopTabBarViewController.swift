//
//  TopTabBarViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.11.2022.
//

import UIKit

protocol TopTabBarViewControllerDelegate: AnyObject {
    func viewController(_ viewController: TopTabBarViewController, didSelectPage index: Int)
}

class TopTabBarViewController: UIViewController {

    private lazy var tabBar: ScrollableSegmentedControl = {
        let cellConfiguration = Style.ScrollableSegmentedControlCell.configuration
        let controlConfiguration = Style.ScrollableSegmentedControl.configuration
        let cells = titles.map { title in
            ScrollableSegmentedControlCell(frame: .zero, title: title, configuration: cellConfiguration)
        }
        let control = ScrollableSegmentedControl(cells: cells, configuration: controlConfiguration)
        control.setSelection(cellIndex: selectedIndex)
        control.addTarget(self, action: #selector(didTapSegment), for: .touchUpInside)

        return control
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.isScrollEnabled = false

        return scrollView
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    weak var navigationDelegate: TopTabBarViewControllerDelegate?

    var selection: ControlSelection {
        return tabBar.selectedSegment
    }
    private (set) var bottomAnchorConstraints: [NSLayoutConstraint] = []
    private let selectedIndex: Int
    private let titles: [String]

    init(titles: [String], selectedIndex: Int = 0) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tabBar)
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        bottomAnchorConstraints = [
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]

        NSLayoutConstraint.activate([
            tabBar.heightAnchor.constraint(equalToConstant: DataEntry.Metric.TabBar.height),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
        ] + bottomAnchorConstraints)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    //NOTE: need to trigger initial selection state when view layout its subviews for first time
    private var didLayoutSubviewsAtFirstTime: Bool = true

    func set(viewControllers: [UIViewController]) {
        viewControllers.forEach { addChild($0) }

        let views = viewControllers.compactMap { $0.view }
        stackView.addArrangedSubviews(views)

        let viewsHeights = views.flatMap { each -> [NSLayoutConstraint] in
            return [
                each.widthAnchor.constraint(equalTo: view.widthAnchor),
                each.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
            ]
        }

        NSLayoutConstraint.activate([
            viewsHeights
        ])

        viewControllers.forEach { $0.didMove(toParent: self) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard scrollView.bounds.width != .zero && didLayoutSubviewsAtFirstTime else {
            return
        }

        didLayoutSubviewsAtFirstTime = false
        selectTab(selection: tabBar.selectedSegment, animated: false)
    }

    @objc private func didTapSegment(_ control: ScrollableSegmentedControl) {
        selectTab(selection: control.selectedSegment, animated: true)
    }

    private func selectTab(selection: ControlSelection, animated: Bool) {
        let index: Int
        switch selection {
        case .selected(let value):
            index = Int(value)
        case .unselected:
            index = 0
        }

        let offset = CGPoint(x: CGFloat(index) * scrollView.bounds.width, y: 0)
        scrollView.setContentOffset(offset, animated: animated)

        navigationDelegate?.viewController(self, didSelectPage: index)
    }
}
