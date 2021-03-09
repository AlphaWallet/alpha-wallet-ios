//
//  Array.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.03.2021.
//

import UIKit

func -<T: Equatable>(left: [T], right: [T]) -> [T] {
    return left.filter { l in
        !right.contains { $0 == l }
    }
}
