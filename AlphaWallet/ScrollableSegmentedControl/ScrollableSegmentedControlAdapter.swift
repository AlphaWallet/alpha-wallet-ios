//
//  ScrollingSegmentedControlAdapter.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 28/12/21.
//

import UIKit

class ScrollableSegmentedControlAdapter: ScrollableSegmentedControl, ReusableTableHeaderViewType {

    static func tokensSegmentControl(titles: [String]) -> ScrollableSegmentedControlAdapter {
        let cellConfiguration = Style.ScrollableSegmentedControlCell.configuration
        let controlConfiguration = Style.ScrollableSegmentedControl.configuration
        let cells = titles.map { title in
            ScrollableSegmentedControlCell(frame: .zero, title: title, configuration: cellConfiguration)
        }
        let control = ScrollableSegmentedControlAdapter(cells: cells, configuration: controlConfiguration)
        control.dummyControl = SegmentedControl(titles: titles)
        control.addTarget(control, action: #selector(handleTap(_:)), for: .touchUpInside)
        control.setSelection(cellIndex: 0)
        return control
    }

    weak var delegate: SegmentedControlDelegate?

    var dummyControl: SegmentedControl?
    var selection: SegmentedControl.Selection = .unselected {
        didSet {
            handleSelection(selection)
        }
    }

    override init(cells: [ScrollableSegmentedControlCell], configuration: ScrollableSegmentedControlConfiguration) {
        super.init(cells: cells, configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap(_ sender: ScrollableSegmentedControl) {
        guard let delegate = delegate, let dummyControl = dummyControl else {
            return
        }
        var selection: SegmentedControl.Selection
        switch sender.selectedSegment {
        case .unselected:
            selection = .unselected
        case .selected(let index):
            selection = .selected(UInt(index))
        }
        delegate.didTapSegment(atSelection: selection, inSegmentedControl: dummyControl)
    }

    private func handleSelection(_ inputSelection: SegmentedControl.Selection) {
        switch inputSelection {
        case .unselected:
            unselect()
        case .selected(let index):
            setSelection(cellIndex: Int(index))
        }
    }

}

