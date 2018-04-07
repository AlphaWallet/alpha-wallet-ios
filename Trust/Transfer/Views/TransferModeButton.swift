// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TransferModeButton: UIControl {
    var title: String = "" {
        didSet {
            label.text = title
        }
    }
    var image: UIImage? {
        didSet {
            imageView.image = image
        }
    }
    let background = UIControl()
    let imageView = UIImageView()
    let label = UILabel()
    var callback: (()->())?

    init() {
        super.init(frame: .zero)

        background.addTarget(self, action: #selector(touchDown), for: .touchDown)
        background.addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
        background.addTarget(self, action: #selector(touchUpOutside), for: .touchUpOutside)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        background.backgroundColor = Colors.appWhite
        background.layer.cornerRadius = 20
        background.layer.shadowRadius = 3
        background.layer.shadowColor = UIColor.black.cgColor
        background.layer.shadowOffset = CGSize(width: 0, height: 0)
        background.layer.shadowOpacity = 0.14
        background.layer.borderColor = UIColor.black.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 0
        addSubview(label)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        let constraintForImageViewTop: NSLayoutConstraint
        if ScreenChecker().isNarrowScreen() {
            constraintForImageViewTop = imageView.topAnchor.constraint(equalTo: topAnchor, constant: 3)
        } else {
            constraintForImageViewTop = imageView.bottomAnchor.constraint(equalTo: centerYAnchor, constant: 7)
        }

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            constraintForImageViewTop,
            imageView.bottomAnchor.constraint(equalTo: label.topAnchor, constant: -3),

            imageView.widthAnchor.constraint(equalToConstant: 70),
            imageView.heightAnchor.constraint(equalToConstant: 70),

            label.leftAnchor.constraint(equalTo: leftAnchor, constant: 10),
            label.rightAnchor.constraint(equalTo: rightAnchor, constant: -10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),

            widthAnchor.constraint(equalTo: heightAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func touchDown() {
        background.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1)
    }
    @objc func touchUpInside() {
        background.backgroundColor = Colors.appWhite
        callback?()
    }
    @objc func touchUpOutside() {
        background.backgroundColor = Colors.appWhite
    }
}
