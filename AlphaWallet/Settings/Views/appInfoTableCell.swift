//
//  appInfoTableCell.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 07/04/20.
//

import UIKit

class AppInfoTableCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    let containerView: UIView = {
           let view = UIView()
           view.translatesAutoresizingMaskIntoConstraints = false
           view.clipsToBounds = true // this will make sure its children do not go out of the boundary
           view.backgroundColor = UIColor.clear
           return view
       }()

    var settings: SettingFooterModel? {
        didSet {
            guard let settingItem = settings else { return }
            if let title = settingItem.title {
                settingTitle.text = title
            }
            if let subtitle = settingItem.subTitle {
                settingSubTitle.text = subtitle
            }
            self.backgroundColor = R.color.alabaster()
        }
    }
    
    let settingTitle: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 15)
        label.textColor = R.color.dove()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let settingSubTitle: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor =  R.color.dove()
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        containerView.addSubview(settingTitle)
        containerView.addSubview(settingSubTitle)
        self.contentView.addSubview(containerView)

        containerView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        containerView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16).isActive = true
        containerView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -22).isActive = true
        containerView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        settingTitle.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor).isActive = true
        settingTitle.centerYAnchor.constraint(equalTo: self.containerView.centerYAnchor).isActive = true

        settingSubTitle.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor).isActive = true
        settingSubTitle.centerYAnchor.constraint(equalTo: self.containerView.centerYAnchor).isActive = true

    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
