//
//  SettingViewHeader.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 08/04/20.
//

import UIKit

class SettingViewHeader: UITableViewHeaderFooterView {
    static let reuseIdentifier = String(describing: self)

    let titleLabel: UILabel = {
           let label = UILabel()
           label.font = UIFont.boldSystemFont(ofSize: 15)
           label.textColor = R.color.dove()
           label.translatesAutoresizingMaskIntoConstraints = false
           return label
       }()
    
    let headerTopSperator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true // this will make sure its children do not go out of the boundary
        view.backgroundColor = R.color.mercury()
        return view
    }()
    
    let headerBottomSperator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true // this will make sure its children do not go out of the boundary
        view.backgroundColor = R.color.mercury()
        return view
    }()

    var title: String? {
        get {
            return titleLabel.text
        }
        set {
            titleLabel.text = newValue
            layoutIfNeeded()
        }
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = R.color.alabaster()
        
        addSubview(titleLabel)
        self.contentView.addSubview(headerTopSperator)
        self.contentView.addSubview(headerBottomSperator)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
    
        headerTopSperator.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        headerTopSperator.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor).isActive = true
        headerTopSperator.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor).isActive = true
        headerTopSperator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        headerBottomSperator.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        headerBottomSperator.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor).isActive = true
        headerBottomSperator.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor).isActive = true
        headerBottomSperator.heightAnchor.constraint(equalToConstant: 1).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
