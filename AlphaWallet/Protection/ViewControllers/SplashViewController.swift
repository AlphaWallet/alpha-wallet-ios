// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class SplashViewController: UIViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let controller = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController() {
            addChild(controller)

            view.addSubview(controller.view)
            view.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                controller.view.topAnchor.constraint(equalTo: view.topAnchor),
                controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            
            controller.didMove(toParent: self)
        }
    }
}
