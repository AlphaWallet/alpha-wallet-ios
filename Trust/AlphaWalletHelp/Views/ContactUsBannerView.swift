// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ContactUsBannerView: UIView {
    let button = UIButton(type: .system)
    let imageView = UIImageView()
    let label = UILabel()
    let bannerHeight = CGFloat(60)

    override init(frame: CGRect) {
        super.init(frame: CGRect())

        let stackView = UIStackView(arrangedSubviews: [imageView, label])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 14
        stackView.distribution = .fill
        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        addSubview(stackView)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addSubview(button)

        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
            stackView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),

            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = UIColor(red: 249, green: 208, blue: 33)

        imageView.image = R.image.onboarding_contact()

        label.textColor = Colors.appText
        label.font = Fonts.light(size: 18)
        label.text = R.string.localizable.aHelpContactFooterButtonTitle()
    }

    @objc func tapped() {
        //TODO show help contact options by firing a delegate method
        print("Tapped contact us")
    }
}
