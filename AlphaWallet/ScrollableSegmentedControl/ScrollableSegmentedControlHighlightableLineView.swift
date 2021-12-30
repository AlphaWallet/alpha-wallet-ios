//
//  HighlightableLineView.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 28/12/21.
//

import UIKit

struct ScrollableSegmentedControlHighlightableLineViewConfiguration {

    let lineHeight: CGFloat
    let highlightHeight: CGFloat
    let lineColor: UIColor
    let highLightColor: UIColor

}

class ScrollableSegmentedControlHighlightableLineView: UIView {

    // MARK: - Properties
    // MARK: Private

    private var lineEndConstraint: NSLayoutConstraint?
    private var lineStartConstraint: NSLayoutConstraint?

    // MARK: Public

    var lineEndOffset: CGFloat = 0 {
        didSet {
            lineEndConstraint?.constant = lineEndOffset
        }
    }

    var lineStartOffset: CGFloat = 0 {
        didSet {
            lineStartConstraint?.constant = lineStartOffset
        }
    }

    // MARK: - Constructors

    init(configuration: ScrollableSegmentedControlHighlightableLineViewConfiguration) {
        super.init(frame: .zero)
        configureView(configuration: configuration)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    // MARK: - Configuration

    private func configureView(configuration: ScrollableSegmentedControlHighlightableLineViewConfiguration) {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = configuration.lineColor
        heightAnchor.constraint(equalToConstant: configuration.lineHeight).isActive = true
        configureLine(configuration: configuration)
    }

    private func configureLine(configuration: ScrollableSegmentedControlHighlightableLineViewConfiguration) {
        let line = UIView()
        line.layer.cornerRadius = configuration.highlightHeight/2.0
        addSubview(line)
        line.backgroundColor = configuration.highLightColor
        line.translatesAutoresizingMaskIntoConstraints = false
        let heightConstraint = line.heightAnchor.constraint(equalToConstant: configuration.highlightHeight)
        let startConstraint = line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0.0)
        let endConstraint = line.trailingAnchor.constraint(equalTo: leadingAnchor, constant: 0.0)
        let bottomConstraint = line.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0.0)
        lineStartConstraint = startConstraint
        lineEndConstraint = endConstraint
        NSLayoutConstraint.activate([startConstraint, endConstraint, heightConstraint, bottomConstraint])
    }

}
