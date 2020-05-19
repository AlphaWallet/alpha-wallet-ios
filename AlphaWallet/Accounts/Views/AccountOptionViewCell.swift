// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AccountOptionViewCellDelegate: class {
    func cell(_ cell: AccountOptionViewCell, didSelectOption sender: UIButton)
}

class AccountOptionViewCell: UITableViewCell {
    static let identifier = "AccountOptionViewCell"

    var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        
        return label
    }()
    
    var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        
        return label
    }()
    
    var accessoryImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = R.image.arrowSystem()?.withRenderingMode(.alwaysTemplate)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = R.color.mercury()
        
        return imageView
    }()
    
    private var separatorLineView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.mercury()
        
        return view
    }()
    
    private var selectionButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }()
    
    private var descriptioLabelView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    private var descriptionLabelSpacer: UIView = .spacer(height: StyleLayout.sideMargin)
    
    weak var delegate: AccountOptionViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        selectionButton.addTarget(self, action: #selector(selectionButtonSelected(_:)), for: .touchUpInside)
        accessoryImageView.setContentHuggingPriority(.required, for: .horizontal)
        accessoryImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let views = [.spacerWidth(20), titleLabel, accessoryImageView, .spacerWidth(6)].asStackView(axis: .horizontal)
        views.translatesAutoresizingMaskIntoConstraints = false
        
        let subViews = [.spacer(height: StyleLayout.sideMargin), views, .spacer(height: StyleLayout.sideMargin), separatorLineView, descriptionLabelSpacer, descriptioLabelView].asStackView(axis: .vertical)
        subViews.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subViews)
        contentView.addSubview(selectionButton)
        descriptioLabelView.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            subViews.anchorsConstraint(to: contentView),
            selectionButton.anchorsConstraint(to: views),
            separatorLineView.heightAnchor.constraint(equalToConstant: 1.0),
            
            accessoryImageView.widthAnchor.constraint(equalToConstant: 30),
            accessoryImageView.heightAnchor.constraint(equalToConstant: 30),
            
            descriptioLabelView.topAnchor.constraint(equalTo: separatorLineView.bottomAnchor),
            descriptioLabelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            descriptioLabelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            descriptioLabelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            descriptionLabel.anchorsConstraint(to: descriptioLabelView, edgeInsets: .init(top: 13, left: 20, bottom: 13, right: 20))
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(viewModel: AccountOptionViewModel) {
        titleLabel.text = viewModel.title
        titleLabel.font = viewModel.titleFont
        titleLabel.textColor = viewModel.titleColor
        
        descriptionLabelSpacer.isHidden = viewModel.description == nil
        descriptioLabelView.isHidden = viewModel.description == nil
        separatorLineView.isHidden = viewModel.description == nil
        descriptionLabel.text = viewModel.description
        descriptionLabel.font = viewModel.descriptionFont
        descriptionLabel.textColor = viewModel.descriptionColor
        descriptionLabel.setLineHeight(lineHeight: 22)
    }
    
    @objc private func selectionButtonSelected(_ sender: UIButton) {
        delegate?.cell(self, didSelectOption: sender)
    }
}
