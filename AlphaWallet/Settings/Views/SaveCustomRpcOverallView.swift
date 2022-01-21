//
//  SaveCustomRpcOverallView.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit

class SaveCustomRpcOverallView: UIView {

    let titles: [String]

    var bottomConstraint: NSLayoutConstraint?

    lazy var segmentedControl: ScrollableSegmentedControl = {
        let cellConfiguration = Style.ScrollableSegmentedControlCell.configuration
        let controlConfiguration = Style.ScrollableSegmentedControl.configuration
        let cells = titles.map { title in
            ScrollableSegmentedControlCell(frame: .zero, title: title, configuration: cellConfiguration)
        }
        let segmentedControl = ScrollableSegmentedControl(cells: cells, configuration: controlConfiguration)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        return segmentedControl
    }()

    lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    convenience init(titles: [String]) {
        self.init(frame: .zero, titles: titles)
    }

    init(frame: CGRect, titles: [String]) {
        self.titles = titles
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configureView() {
        configureSegmentedControl()
        configureContainerView()
    }

    private func configureSegmentedControl() {
        addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func configureContainerView() {
        addSubview(containerView)
        bottomConstraint = containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomConstraint!
        ])
    }

}
