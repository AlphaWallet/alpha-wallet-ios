// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class AddHideTokenSectionHeaderView: UITableViewHeaderFooterView {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Fonts.bold(size: 24)
        label.textColor = .black
        
        return label
    }()
    
    var rightAccessoryView: UIView? {
        didSet {
            if let view = rightAccessoryView {
                setup(rightAccessoryView: view)
            } else if let oldValue = oldValue {
                oldValue.removeFromSuperview()
            }
        }
    }
    
    private var separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        return nil
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        setupViews()
    }
    
    private func setupViews() {
        backgroundColor = .white
        contentView.backgroundColor = .white
        addSubview(titleLabel)
        addSubview(separatorView)
        
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            separatorView.widthAnchor.constraint(equalTo: widthAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setup(rightAccessoryView: UIView) {
        addSubview(rightAccessoryView)
        
        NSLayoutConstraint.activate([
            rightAccessoryView.widthAnchor.constraint(equalTo: widthAnchor),
            rightAccessoryView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }
    
    func configure(viewModel: AddHideTokenSectionHeaderViewModel) {
        titleLabel.text = viewModel.text
        separatorView.backgroundColor = viewModel.separatorColor
    }
}
