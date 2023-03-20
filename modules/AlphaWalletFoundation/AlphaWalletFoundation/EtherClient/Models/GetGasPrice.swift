//
//  GetGasPrice.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.08.2022.
//

import Foundation
import BigInt
import APIKit
import JSONRPCKit
import Combine
import AlphaWalletCore

public typealias APIKitSession = APIKit.Session
public typealias SessionTaskError = APIKit.SessionTaskError
public typealias JSONRPCError = JSONRPCKit.JSONRPCError

extension SessionTaskError {
    init(error: Error) {
        if let e = error as? SessionTaskError {
            self = e
        } else {
            self = .responseError(error)
        }
    }

    public var unwrapped: Error {
        switch self {
        case .connectionError(let e):
            return e
        case .requestError(let e):
            return e
        case .responseError(let e):
            return e
        }
    }
}
