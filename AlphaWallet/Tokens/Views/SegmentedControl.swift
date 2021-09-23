// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol SegmentedControlDelegate: AnyObject {
    //Implementations of this protocol function will have to cast `segment` to the appropriate type. Maybe some generic or associated type magic can fix this, but alas time constraints
    func didTapSegment(atSelection selection: SegmentedControl.Selection, inSegmentedControl segmentedControl: SegmentedControl)
}

extension SegmentedControl {
    static func tokensSegmentControl(titles: [String]) -> SegmentedControl {
        let isNarrowScreen = ScreenChecker().isNarrowScreen
        let spacing: CGFloat = isNarrowScreen ? 30 : 40
        let inset: CGFloat = isNarrowScreen ? 7 : 20

        return .init(titles: titles, segmentConfiguration: .init(spacing: spacing, selectionIndicatorInsets: .init(top: 0, left: inset, bottom: 0, right: inset), selectionBarHeight: 3, barHeight: 1))
    }
}

class SegmentedControl: UIView, ReusableTableHeaderViewType {
    enum Alignment {
        case left
        case right
        case center
    }

    enum Selection: Equatable {
        case selected(UInt)
        case unselected
    }

    private let buttons: [UIButton]
    private let highlightedBar = UIView()
    private var highlightBarHorizontalConstraints: [NSLayoutConstraint]?
    private lazy var viewModel = SegmentedControlViewModel(selection: selection)

    weak var delegate: SegmentedControlDelegate?
    var selection: Selection = .selected(0) {
        didSet {
            if oldValue == selection { return }
            viewModel.selection = selection
            configureTitleButtons()
            configureHighlightedBar()
        }
    }

    struct SegmentConfiguration {
        var spacing: CGFloat = 20
        var selectionIndicatorInsets: UIEdgeInsets = .init(top: 0, left: 7, bottom: 0, right: 7)
        var selectionBarHeight: CGFloat = 3
        var barHeight: CGFloat = 1
    }

    private let segmentConfiguration: SegmentConfiguration

    init(titles: [String], alignment: Alignment = .left, distribution: UIStackView.Distribution = .fill, segmentConfiguration: SegmentConfiguration = .init()) {
        self.buttons = SegmentedControl.createButtons(fromTitles: titles)
        self.segmentConfiguration = segmentConfiguration
        super.init(frame: .zero)

        backgroundColor = viewModel.backgroundColor

        for each in buttons {
            each.addTarget(self, action: #selector(segmentTapped), for: .touchUpInside)
        }
        let buttonsStackView = buttons.map { $0 as UIView }.asStackView(distribution: distribution, spacing: segmentConfiguration.spacing)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonsStackView)

        let fullWidthBar = UIView()
        fullWidthBar.translatesAutoresizingMaskIntoConstraints = false
        fullWidthBar.backgroundColor = viewModel.unselectedBarColor
        addSubview(fullWidthBar)

        highlightedBar.translatesAutoresizingMaskIntoConstraints = false
        fullWidthBar.addSubview(highlightedBar)

        let barHeightConstraint = fullWidthBar.heightAnchor.constraint(equalToConstant: segmentConfiguration.barHeight)
        barHeightConstraint.priority = .defaultHigh

        var contraints: [NSLayoutConstraint] = []

        switch alignment {
        case .left:
            let stackViewLeadingConstraint = buttonsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 17)
            stackViewLeadingConstraint.priority = .defaultHigh

            let stackViewWidthConstraint = buttonsStackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -17)
            stackViewWidthConstraint.priority = .defaultHigh

            contraints = [stackViewLeadingConstraint, stackViewWidthConstraint]
        case .center:
            let stackViewCenterConstraint = buttonsStackView.centerXAnchor.constraint(equalTo: centerXAnchor)
            stackViewCenterConstraint.priority = .defaultHigh

            let stackViewWidthConstraint = buttonsStackView.widthAnchor.constraint(equalTo: widthAnchor, constant: -34)
            stackViewWidthConstraint.priority = .defaultHigh

            contraints = [stackViewCenterConstraint, stackViewWidthConstraint]
        case .right:
            let stackViewLeadingConstraint = buttonsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -17)
            stackViewLeadingConstraint.priority = .defaultHigh

            let stackViewWidthConstraint = buttonsStackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -17)
            stackViewWidthConstraint.priority = .defaultHigh

            contraints = [stackViewLeadingConstraint, stackViewWidthConstraint]
        }

        NSLayoutConstraint.activate(contraints + [
            buttonsStackView.topAnchor.constraint(equalTo: topAnchor),
            buttonsStackView.bottomAnchor.constraint(equalTo: fullWidthBar.topAnchor),

            fullWidthBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            fullWidthBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            barHeightConstraint,
            fullWidthBar.bottomAnchor.constraint(equalTo: bottomAnchor),

            highlightedBar.heightAnchor.constraint(equalToConstant: segmentConfiguration.selectionBarHeight),
            highlightedBar.bottomAnchor.constraint(equalTo: fullWidthBar.bottomAnchor),
        ])

        configureTitleButtons()
        configureHighlightedBar()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private static func createButtons(fromTitles titles: [String]) -> [UIButton] {
        return titles.map {
            let button = UIButton(type: .system)
            button.setTitle($0, for: .normal)
            return button
        }
    }

    @objc private func segmentTapped(_ source: UIButton) {
        guard let segment = buttons.firstIndex(of: source).flatMap({ UInt($0) }) else { return }
        delegate?.didTapSegment(atSelection: .selected(segment), inSegmentedControl: self)
    }

    func configureTitleButtons() {
        for (index, each) in buttons.enumerated() {
            //This is safe only because index can't possibly be negative
            let index = UInt(index)
            each.setTitleColor(viewModel.titleColor(forSelection: .selected(index)), for: .normal)
            each.titleLabel?.font = viewModel.titleFont(forSelection: .selected(index))
        }
    }

    func configureHighlightedBar() {
        switch selection {
        case .selected(let index):
            highlightedBar.backgroundColor = viewModel.selectedBarColor
            let index = Int(index)
            let button: UIButton = buttons[index]
            if let previousConstraints = highlightBarHorizontalConstraints {
                NSLayoutConstraint.deactivate(previousConstraints)
            }
            highlightBarHorizontalConstraints = [
                highlightedBar.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: -segmentConfiguration.selectionIndicatorInsets.left),
                highlightedBar.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: segmentConfiguration.selectionIndicatorInsets.right),
            ]
            if let constraints = highlightBarHorizontalConstraints {
                NSLayoutConstraint.activate(constraints)
            }
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 10, options: .allowUserInteraction, animations: {
                self.layoutIfNeeded()
            })
        case .unselected:
            highlightedBar.backgroundColor = nil
        }
    }
}
