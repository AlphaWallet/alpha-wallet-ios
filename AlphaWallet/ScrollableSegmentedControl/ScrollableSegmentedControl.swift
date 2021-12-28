//
//  ScrollableSegmentedControl.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 27/12/21.
//

import UIKit

struct ScrollableSegmentedControlConfiguration {

    let lineConfiguration: ScrollableSegmentedControlHighlightableLineViewConfiguration
    let isProportionalWidth: Bool
    let cellSpacing: CGFloat
    let alignmentWhenNotScrollable: ScrollableSegmentedControl.Alignment
    let animationDuration: TimeInterval
    let animationCurve: UIView.AnimationCurve

}

class ScrollableSegmentedControl: UIControl {

    enum Selection {
        case unselected
        case selected(Int)
    }

    // Only if not scrollable (total cells width + spacing < control width).

    enum Alignment {
        case leading
        case trailing
        case centered
        case filled
    }

    // MARK: - Properties
    // MARK: Private

    private let cells: [ScrollableSegmentedControlCell]
    private let configuration: ScrollableSegmentedControlConfiguration
    private var intrinsicContentWidth: CGFloat = 0.0
    private var previousHeight: CGFloat = 0.0
    private var previousWidth: CGFloat = 0.0
    private var scrollViewHeightConstraint: NSLayoutConstraint?
    private var scrollViewPositionConstraints: [NSLayoutConstraint] = []
    private var _selectedSegment: Selection = .unselected

    // MARK: Public

    var selectedSegment: Selection {
        return _selectedSegment
    }

    // MARK: - UI Elements

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var line: ScrollableSegmentedControlHighlightableLineView = {
        let line = ScrollableSegmentedControlHighlightableLineView(configuration: self.configuration.lineConfiguration)
        line.translatesAutoresizingMaskIntoConstraints = false
        return line
    }()

    // MARK: - Constructors
    // Proportional means variable width of cells due to content, if not then all cells are the same width based on the largest cell width. leading, centred, trailing just places the cells in those positions if the cells are shorter than the width of the control. Filled has two types, filled with proportional and filled with non-proportional. The proportional type simply divides the left over width amongst the cells equally so each cell can have a different width. The non-proportional type simply makes every cell the same width based on the width of the frame and the number of cells.

    init(cells: [ScrollableSegmentedControlCell], configuration: ScrollableSegmentedControlConfiguration) {
        self.cells = cells
        self.configuration = configuration
        super.init(frame: .zero)
        if configuration.isProportionalWidth {
            configureProportionalWidthCells()
        } else {
            configureEqualWidthCells()
        }
        configureHighlightLine()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func layoutSubviews() {
        super.layoutSubviews()
        var updated: Bool = false
        if previousHeight != bounds.height {
            previousHeight = bounds.height
            cells.forEach { cell in
                cell.height = bounds.height
            }
            scrollViewHeightConstraint?.constant = bounds.height
            updated = true
        }
        if previousWidth != bounds.width {
            previousWidth = bounds.width
            removeConstraints(scrollViewPositionConstraints)
            scrollViewPositionConstraints = []
            if intrinsicContentWidth < bounds.width {
                switch configuration.alignmentWhenNotScrollable {
                case .leading:
                    configureScrollViewLeading()
                case .trailing:
                    configureScrollViewTrailing()
                case .centered:
                    configureScrollViewCentered()
                case .filled:
                    configuration.isProportionalWidth ? configureScrollViewFilledProportional() : configureScrollViewFilledNotProportional()
                }
            } else {
                configureScrollViewScrolling()
            }
            NSLayoutConstraint.activate(scrollViewPositionConstraints)
            updated = true
        }
        if updated {
            scrollView.updateConstraintsIfNeeded()
        }
    }

    // MARK: - Set selection
    // MARK: Public

    func setSelection(cellIndex: Int) {
        guard cellIndex < cells.count, cellIndex >= 0 else { return }
        _selectedSegment = .selected(cellIndex)
        highlightCell(cellIndex: cellIndex)
    }

    func setSelection(cell: ScrollableSegmentedControlCell) {
        guard let cellIndex = cells.firstIndex(of: cell) else { return }
        _selectedSegment = .selected(cellIndex)
        highlightCell(cellIndex: cellIndex)
    }

    func unselect() {
        _selectedSegment = .unselected
        unhighlightLine()
    }

    // MARK: Private

    private func highlightCell(cellIndex: Int) {
        guard cellIndex >= 0, cellIndex < cells.count else { return }
        let animation = UIViewPropertyAnimator(duration: configuration.animationDuration, curve: configuration.animationCurve) {
            self.unhighlightAllCells()
            let highlightedCell = self.cells[cellIndex]
            if highlightedCell.frame.size == .zero {
                // Cell is not yet rendered so we loop until it is. This only happens the first time the control is rendered in a tableview as a header.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.highlightCell(cellIndex: cellIndex)
                }
                return
            }
            highlightedCell.highlighted = true
            let frame = self.line.convert(highlightedCell.bounds, from: highlightedCell)
            self.line.lineStartOffset = frame.minX
            self.line.lineEndOffset = frame.maxX
            self.line.layoutIfNeeded()
            self.scrollView.scrollRectToVisible(highlightedCell.frame, animated: true)
        }
        animation.startAnimation()
    }

    private func unhighlightLine() {
        let animation = UIViewPropertyAnimator(duration: configuration.animationDuration, curve: configuration.animationCurve) {
            self.line.lineStartOffset = 0
            self.line.lineEndOffset = 0
            self.unhighlightAllCells()
            self.line.layoutIfNeeded()
        }
        animation.startAnimation()
    }

    private func unhighlightAllCells() {
        cells.forEach { cell in
            cell.highlighted = false
        }
    }

    // MARK: - Configurations

    private func configureScrollViewLeading() {
        scrollViewPositionConstraints.append(scrollView.leadingAnchor.constraint(equalTo: leadingAnchor))
        scrollViewPositionConstraints.append(scrollView.widthAnchor.constraint(equalToConstant: intrinsicContentWidth))
    }

    private func configureScrollViewCentered() {
        scrollViewPositionConstraints.append(scrollView.centerXAnchor.constraint(equalTo: centerXAnchor))
        scrollViewPositionConstraints.append(scrollView.widthAnchor.constraint(equalToConstant: intrinsicContentWidth))
    }

    private func configureScrollViewTrailing() {
        scrollViewPositionConstraints.append(scrollView.widthAnchor.constraint(equalToConstant: intrinsicContentWidth))
        scrollViewPositionConstraints.append(scrollView.trailingAnchor.constraint(equalTo: trailingAnchor))
    }

    private func configureScrollViewScrolling() {
        scrollViewPositionConstraints.append(scrollView.leadingAnchor.constraint(equalTo: leadingAnchor))
        scrollViewPositionConstraints.append(scrollView.trailingAnchor.constraint(equalTo: trailingAnchor))
    }

    private func configureScrollViewFilledNotProportional() {
        scrollViewPositionConstraints.append(scrollView.leadingAnchor.constraint(equalTo: leadingAnchor))
        scrollViewPositionConstraints.append(scrollView.trailingAnchor.constraint(equalTo: trailingAnchor))
        let numberOfCells: Int = cells.count
        let cellSpacingWidth: CGFloat = configuration.cellSpacing * CGFloat(numberOfCells + 1)
        let filledWidth: CGFloat = (bounds.width - cellSpacingWidth) / CGFloat(numberOfCells)
        cells.forEach { cell in
            cell.width = filledWidth
        }
    }

    private func configureScrollViewFilledProportional() {
        scrollViewPositionConstraints.append(scrollView.leadingAnchor.constraint(equalTo: leadingAnchor))
        scrollViewPositionConstraints.append(scrollView.trailingAnchor.constraint(equalTo: trailingAnchor))
        let numberOfCells: Int = cells.count
        intrinsicContentWidth = 0
        cells.forEach { cell in
            cell.cellPadding = 0
            intrinsicContentWidth += cell.intrinsicWidth
        }
        let cellPadding = (bounds.width - intrinsicContentWidth)/(2.0 * CGFloat(numberOfCells))
        cells.forEach { cell in
            cell.cellPadding = cellPadding
            cell.width = cell.intrinsicWidth
        }
    }

    private func configureProportionalWidthCells() {
        configureCells()
    }

    private func configureEqualWidthCells() {
        let maxWidth = cells.reduce(into: CGFloat(0.0)) { currentMaxWidth, cell in
            currentMaxWidth = max(currentMaxWidth, cell.intrinsicWidth)
        }
        cells.forEach { cell in
            cell.width = maxWidth
        }
        configureCells()
        intrinsicContentWidth = (maxWidth * CGFloat(cells.count)) + (configuration.cellSpacing * CGFloat((cells.count + 1)))
    }

    private func configureCells() {
        var previousCell: ScrollableSegmentedControlCell?
        var constraints: [NSLayoutConstraint] = []
        cells.forEach { cell in
            scrollView.addSubview(cell)
            if let previousCell = previousCell {
                // attach leading view of current cell to trailing view of previous cell
                constraints.append(cell.leadingAnchor.constraint(equalTo: previousCell.trailingAnchor, constant: configuration.cellSpacing))
            } else {
                // attach leading view of current cell to leading view of scrollview
                constraints.append(cell.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: configuration.cellSpacing))
            }
            constraints.append(cell.topAnchor.constraint(equalTo: scrollView.topAnchor))
            constraints.append(cell.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor))
            previousCell = cell
            cell.delegate = self
            intrinsicContentWidth += (cell.intrinsicWidth + configuration.cellSpacing)
        }
        // attach trailing view of last cell to trailing view of scrollview
        if let previousCell = previousCell {
            constraints.append(previousCell.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -configuration.cellSpacing))
            intrinsicContentWidth += configuration.cellSpacing
        }
        addSubview(scrollView)
        configureScrollViewScrolling() // default when frame is zero
        constraints.append(scrollView.topAnchor.constraint(equalTo: topAnchor))
        constraints.append(scrollView.bottomAnchor.constraint(equalTo: bottomAnchor))
        constraints.append(contentsOf: scrollViewPositionConstraints)
        let heightConstraint = scrollView.heightAnchor.constraint(equalToConstant: 0.0)
        heightConstraint.priority = .defaultLow
        previousHeight = 0.0
        constraints.append(heightConstraint)
        scrollViewHeightConstraint = heightConstraint
        NSLayoutConstraint.activate(constraints)
        translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = false
    }

    private func configureHighlightLine() {
        scrollView.addSubview(line)
        guard let firstCell = cells.first, let lastCell = cells.last else { return }
        NSLayoutConstraint.activate([
            line.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: -firstCell.cellPadding),
            line.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: lastCell.cellPadding)
        ])
    }

}

// MARK: - SegmentedControlCellDelegate

extension ScrollableSegmentedControl: ScrollableSegmentedControlCellDelegate {

    func didSelect(cell: ScrollableSegmentedControlCell, event: UIControl.Event) {
        setSelection(cell: cell)
        sendActions(for: event)
    }

}
