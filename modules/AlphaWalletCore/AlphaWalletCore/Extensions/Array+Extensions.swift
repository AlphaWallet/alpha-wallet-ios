// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import Foundation
import BigInt

public func - <T: Equatable> (left: [T], right: [T]) -> [T] {
    return left.filter { l in
        !right.contains { $0 == l }
    }
}
