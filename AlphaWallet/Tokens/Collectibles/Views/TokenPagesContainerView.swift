//
//  PagesContainerView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit

protocol PageViewType: UIView {
    var title: String { get }
    var rightBarButtonItem: UIBarButtonItem? { get set }
}

protocol PagesContainerViewDelegate: class {
    func containerView(_ containerView: PagesContainerView, didSelectPage index: Int)
}

class PagesContainerView: RoundedBackground {

    private lazy var tabBar: ScrollableSegmentedControl = {
        let titles = pages.map { $0.title }
        let cellConfiguration = Style.ScrollableSegmentedControlCell.configuration
        let controlConfiguration = Style.ScrollableSegmentedControl.configuration
        let cells = titles.map { title in
            ScrollableSegmentedControlCell(frame: .zero, title: title, configuration: cellConfiguration)
        }
        let control = ScrollableSegmentedControl(cells: cells, configuration: controlConfiguration)
        control.setSelection(cellIndex: selectedIndex)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)
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
    let pages: [PageViewType]
    weak var delegate: PagesContainerViewDelegate?

    var selection: ControlSelection {
        return tabBar.selectedSegment
    }
    private (set) var bottomAnchorConstraints: [NSLayoutConstraint] = []
    private let selectedIndex: Int

    init(pages: [PageViewType], selectedIndex: Int = 0) {
        self.pages = pages
        self.selectedIndex = selectedIndex
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(tabBar)
        addSubview(scrollView)
        scrollView.addSubview(stackView)

        let pages = pages.map { $0 }
        stackView.addArrangedSubviews(pages)

        let viewsHeights = pages.flatMap { view -> [NSLayoutConstraint] in
            return [
                view.widthAnchor.constraint(equalTo: widthAnchor),
                view.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
            ]
        }
        bottomAnchorConstraints = [
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]

        NSLayoutConstraint.activate([
            tabBar.heightAnchor.constraint(equalToConstant: 50),
            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
        ] + viewsHeights + bottomAnchorConstraints)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    //NOTE: need to triggle initial selection state when view layout its subviews for first time
    private var didLayoutSubviewsAtFirstTime: Bool = true

    override func layoutSubviews() {
        super.layoutSubviews()

        guard scrollView.bounds.width != .zero && didLayoutSubviewsAtFirstTime else {
            return
        }

        didLayoutSubviewsAtFirstTime = false
        selectTab(selection: tabBar.selectedSegment, animated: false)
    }

    @objc func didTapSegment(_ control: ScrollableSegmentedControl) {
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

        delegate?.containerView(self, didSelectPage: index)
    }
}

class PageViewWithFooter: UIView, PageViewType {

    var title: String {
        pageView.title
    }

    private let pageView: PageViewType
    private let footerBar: ButtonsBarBackgroundView

    var rightBarButtonItem: UIBarButtonItem? {
        get {
            pageView.rightBarButtonItem
        }
        set {
            pageView.rightBarButtonItem = newValue
        }
    }

    init(pageView: PageViewType, footerBar: ButtonsBarBackgroundView) {
        self.pageView = pageView
        self.footerBar = footerBar
        super.init(frame: .zero)

        let stackView = [
            pageView,
            footerBar
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    } 
}
