// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct OnboardingPageViewModel {
    var title: String
    var image: UIImage

    init() {
        title = ""
        image = #imageLiteral(resourceName: "onboarding_lock")
    }

    init(title: String, image: UIImage) {
        self.title = title
        self.image = image
    }
}
