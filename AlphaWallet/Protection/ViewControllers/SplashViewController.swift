// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class SplashViewController: UIViewController {
    private var splashView = SplashView()

    init() {
        super.init(nibName: nil, bundle: nil)
        splashView.translatesAutoresizingMaskIntoConstraints = false
        splashView.frame =  UIScreen.main.bounds
        view.addSubview(splashView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            splashView.topAnchor.constraint(equalToSystemSpacingBelow: guide.topAnchor, multiplier: 1.0),
            splashView.bottomAnchor.constraint(equalToSystemSpacingBelow: guide.bottomAnchor, multiplier: 1.0)
        ])
        splashView.layoutSubviews()
    }
     required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
