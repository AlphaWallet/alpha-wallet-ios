//
//  AnyCancellable.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation
import Combine

extension Set where Element: AnyCancellable {
    public mutating func cancellAll() {
        for each in self {
            each.cancel()
        }

        removeAll()
    }
}
