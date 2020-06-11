// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class SplashView: UIView {
    let logoImageView = UIImageView(image: R.image.launch_icon())

    init() {
        super.init(frame: CGRect.zero)
        backgroundColor = .white
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoImageView)
        self.layoutSubviews()
    }
    override func layoutSubviews() {
        let guide = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
