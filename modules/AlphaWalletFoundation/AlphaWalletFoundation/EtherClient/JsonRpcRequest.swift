// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct UndefinedError: LocalizedError { public init() {} }
public struct UnknownError: LocalizedError { public init() {} }

public enum SessionTaskError: Error {
    /// Error of `URLSession`.
    case connectionError(Error)

    /// Error while creating `URLRequest` from `Request`.
    case requestError(Error)

    /// Error while creating `Request.Response` from `(Data, URLResponse)`.
    case responseError(Error)

    public init(error: Error) {
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

extension URL {
    func generateBasicAuthCredentialsHeaders() -> [String: String] {
        guard let username = user, let password = password  else { return [:] }
        guard let authorization = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() else { return [:] }

        return ["Authorization": "Basic \(authorization)"]
    }
}

extension Dictionary {
    static func += (lhs: inout Self, rhs: Self) {
        lhs.merge(rhs) { _, new in new }
    }

    func merging(with other: [Key: Value]) -> Self {
        var s = self
        for (k, v) in other {
            s.updateValue(v, forKey: k)
        }

        return s
    }
}
