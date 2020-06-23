// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct OnboardingPageViewModel {
    let title: String
    let image: UIImage

    init() {
        title = ""
        image = R.image.onboarding_lock()!
    }

    init(title: String, image: UIImage) {
        self.title = title
        self.image = image
    }
}
