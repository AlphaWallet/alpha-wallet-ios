//
//  SeedPhraseSuggestionViewCell.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 02/05/20.
//
import UIKit

class SeedPhraseSuggestionViewCell: UICollectionViewCell {
    let viewContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.alabaster()
        return view
    }()

     let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = R.color.mine()
        return label
    }()
    
    required init?(coder aDecoder: NSCoder) {
       super.init(coder: aDecoder)
    }
    override init(frame: CGRect) {
        super.init(frame: .zero)

        viewContainer.addSubview(textLabel)
        contentView.addSubview(viewContainer)

        viewContainer.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        viewContainer.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        viewContainer.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
        viewContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        
        textLabel.topAnchor.constraint(equalTo: viewContainer.topAnchor, constant: 10 ).isActive = true
        textLabel.leftAnchor.constraint(equalTo: viewContainer.leftAnchor, constant: 10).isActive = true
        textLabel.rightAnchor.constraint(equalTo: viewContainer.rightAnchor, constant: -10).isActive = true
        textLabel.bottomAnchor.constraint(equalTo: viewContainer.bottomAnchor, constant: -10).isActive = true
        
        viewContainer.layer.cornerRadius = 4
    }
}
