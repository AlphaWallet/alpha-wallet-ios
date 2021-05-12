//
//  TokenPagesContainerView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit

protocol TokenPageViewType: UIView {
    var title: String { get }
}

class TokenPagesContainerView: RoundedBackground {

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
    private let pages: [TokenPageViewType]

    init(pages: [TokenPageViewType]) {
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

extension TokenPagesContainerView: SegmentedControlDelegate {

    func didTapSegment(atSelection selection: SegmentedControl.Selection, inSegmentedControl segmentedControl: SegmentedControl) {
        tabBar.selection = selection
        let index: UInt
        switch selection {
        case .selected(let value):
            index = value
        case .unselected:
            index = 0
        }

        let offset = CGPoint(x: CGFloat(index) * scrollView.bounds.width, y: 0)
        scrollView.setContentOffset(offset, animated: false)
    }
}
