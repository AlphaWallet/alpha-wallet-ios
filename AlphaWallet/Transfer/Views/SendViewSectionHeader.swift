//
//  SendViewSectionHeader.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2020.
//

import UIKit

class SendViewSectionHeader: UIView {
    
    private let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        
        return label
    }()
    
    private let topSeparatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let bottomSeparatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var topSeparatorLineHeight: NSLayoutConstraint!
    
    init() {
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private let separatorHeight: CGFloat = 1
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(topSeparatorView)
        addSubview(textLabel)
        addSubview(bottomSeparatorView)

        topSeparatorLineHeight = topSeparatorView.heightAnchor.constraint(equalToConstant: separatorHeight)
        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(greaterThanOrEqualTo: trailingAnchor, constant: -16),
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13),
            
            topSeparatorView.topAnchor.constraint(equalTo: topAnchor, constant: -separatorHeight),
            topSeparatorView.widthAnchor.constraint(equalTo: widthAnchor),
            
            bottomSeparatorView.topAnchor.constraint(equalTo: bottomAnchor, constant: -separatorHeight),
            bottomSeparatorView.widthAnchor.constraint(equalTo: widthAnchor),
            bottomSeparatorView.heightAnchor.constraint(equalToConstant: separatorHeight),
            topSeparatorLineHeight
        ])
    }
    
    func configure(viewModel: SendViewSectionHeaderViewModel) {
        textLabel.text = viewModel.text
        textLabel.textColor = viewModel.textColor
        textLabel.font = viewModel.font
        backgroundColor = viewModel.backgroundColor
        topSeparatorView.backgroundColor = viewModel.separatorBackgroundColor
        bottomSeparatorView.backgroundColor = viewModel.separatorBackgroundColor
        topSeparatorLineHeight.constant = viewModel.showTopSeparatorLine ? 1 : 0
    }
}

