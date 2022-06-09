//
//  SwapProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import Foundation
import Combine

protocol SwapProvider {
    var name: AnyPublisher<String, Never> { get }
    var fee: AnyPublisher<String, Never> { get }
    var info: AnyPublisher<String, Never> { get }
}
