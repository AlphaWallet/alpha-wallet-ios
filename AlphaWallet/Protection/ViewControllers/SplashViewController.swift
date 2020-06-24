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
        NSLayoutConstraint.activate([
            splashView.topAnchor.constraint(equalToSystemSpacingBelow: view.topAnchor, multiplier: 1.0),
            splashView.bottomAnchor.constraint(equalToSystemSpacingBelow: view.bottomAnchor, multiplier: 1.0),
            splashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splashView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        splashView.layoutSubviews()
    }

     required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
