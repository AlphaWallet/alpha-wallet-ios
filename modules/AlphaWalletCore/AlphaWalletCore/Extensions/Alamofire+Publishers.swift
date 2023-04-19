//
//  Alamofire+Publishers.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Combine
import Alamofire

public enum PromiseError: Error {
    case some(error: Error)

    public init(error: Error) {
        if let e = error as? PromiseError {
            self = e
        } else {
            self = .some(error: error)
        }
    }
    
    public var embedded: Error {
        switch self {
        case .some(let error):
            return error
        }
    }
}
