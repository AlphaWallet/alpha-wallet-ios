// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import UIKit

extension UITextField {

    var textPublisher: AnyPublisher<String?, Never> {
        return Publishers
            .Merge(publisher(forEvent: .editingDidBegin), publisher(forEvent: .editingChanged))
            .map { _ -> String? in self.text }
            .eraseToAnyPublisher()
    }
}
