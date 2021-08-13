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

    private lazy var tabBar: SegmentedControl = {
        let titles = pages.map { $0.title }
        let control = SegmentedControl(titles: titles, alignment: .center, distribution: .fillEqually)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.delegate = self

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

    var selection: SegmentedControl.Selection {
        return tabBar.selection
    }

    init(pages: [PageViewType]) {
        self.pages = pages
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

        NSLayoutConstraint.activate([
            tabBar.heightAnchor.constraint(equalToConstant: 50),
            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ] + viewsHeights)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension PagesContainerView: SegmentedControlDelegate {

    func didTapSegment(atSelection selection: SegmentedControl.Selection, inSegmentedControl segmentedControl: SegmentedControl) {
        tabBar.selection = selection
        let index: Int
        switch selection {
        case .selected(let value):
            index = Int(value)
        case .unselected:
            index = 0
        }

        let offset = CGPoint(x: CGFloat(index) * scrollView.bounds.width, y: 0)
        scrollView.setContentOffset(offset, animated: true)

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
