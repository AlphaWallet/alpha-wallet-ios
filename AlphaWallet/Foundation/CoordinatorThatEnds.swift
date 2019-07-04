// Copyright © 2019 Stormbird PTE. LTD.

import Foundation

protocol CoordinatorThatEnds: Coordinator {
    func endUserInterface(animated: Bool)
    func end()
}
