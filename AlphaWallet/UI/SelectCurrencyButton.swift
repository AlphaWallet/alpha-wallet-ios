//
//  SelectCurrencyButton.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.05.2020.
//

import UIKit

class SelectCurrencyButton: UIControl {

    private let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.font = DataEntry.Font.amountTextField
        
        return label
    }()
    
    private let expandImageView: UIImageView = {
        let imageView = UIImageView(image: R.image.expandMore())
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.contentMode = .scaleAspectFit
        
        return imageView
    }()
    
    private let currencyIconImageView: UIImageView = {
        let imageView = UIImageView(image: #imageLiteral(resourceName: "eth"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.contentMode = .scaleAspectFit
        
        return imageView
    }()
    
    private let actionButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    var text: String {
        get {
            return textLabel.text ?? ""
        }
        set {
            textLabel.text = newValue
        }
    }
    
    var image: UIImage? {
        get {
            return currencyIconImageView.image
        }
        set {
            currencyIconImageView.image = newValue
        }
    }
    
    init() {
        super.init(frame: .zero)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        
        let stackView = [currencyIconImageView, .spacerWidth(7), textLabel, .spacerWidth(10), expandImageView].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        addSubview(actionButton)
        
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        
        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
            actionButton.anchorsConstraint(to: self),
            currencyIconImageView.widthAnchor.constraint(equalToConstant: 40),
            currencyIconImageView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    override func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        actionButton.addTarget(target, action: action, for: controlEvents)
    }

}

