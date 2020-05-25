//
//  SettingViewHeader.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 08/04/20.
//

import UIKit

class SettingViewHeader: UITableViewHeaderFooterView {
    static let reuseIdentifier = String(describing: self)

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        return label
    }()
    
    private let topSperator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()
        return view
    }()
    
    private let bottomSperator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()
        return view
    }()
    
    private var topSeparatorHeight: NSLayoutConstraint!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        let stackView = [
            topSperator,
            .spacer(height: 13, backgroundColor: .clear),
            [.spacerWidth(16), titleLabel, detailsLabel, .spacerWidth(16)].asStackView(axis: .horizontal),
            .spacer(height: 13, backgroundColor: .clear),
            bottomSperator
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: contentView),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bottomSperator.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        topSeparatorHeight = topSperator.heightAnchor.constraint(equalToConstant: 1)
        topSeparatorHeight.isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(viewModel: SettingViewHeaderViewModel) {
        titleLabel.text = viewModel.titleText
        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.font = viewModel.titleTextFont
     
        detailsLabel.text = viewModel.detailsText
        detailsLabel.textColor = viewModel.detailsTextColor
        detailsLabel.font = viewModel.detailsTextFont
        topSperator.backgroundColor = viewModel.separatorColor
        bottomSperator.backgroundColor = viewModel.separatorColor
        contentView.backgroundColor = viewModel.backgoundColor
        topSeparatorHeight.constant = viewModel.showTopSeparator ? 1 : 0
    }
}
