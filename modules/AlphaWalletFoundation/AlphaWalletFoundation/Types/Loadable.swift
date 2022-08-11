// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public enum Loadable<T, F> {
    case loading
    case done(T)
    case failure(F)
}

extension Loadable {
    public var value: T? {
        switch self {
        case .loading, .failure:
            return nil
        case .done(let t):
            return t
        }
    }

    public func mapValue<T2>(_ block: (T) -> T2) -> Loadable<T2, F> {
        switch self {
        case .loading:
            return .loading
        case .done(let t):
            return .done(block(t))
        case .failure(let f):
            return .failure(f)
        }
    }

    public func map<T2>(_ block: (T) -> Loadable<T2, F>) -> Loadable<T2, F> {
        switch self {
        case .loading:
            return .loading
        case .done(let t):
            return block(t)
        case .failure(let f):
            return .failure(f)
        }
    }
}

extension Loadable: Equatable where T: Equatable, F: Equatable {
    public static func == (lhs: Loadable<T, F>, rhs: Loadable<T, F>) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.done(let v1), .done(let v2)):
            return v1 == v2
        case (.failure(let f1), .failure(let f2)):
            return f1 == f2
        case (.done, .loading), (.failure, .done), (.failure, .loading), (.loading, .failure), (.loading, .done), (.done, .failure):
            return false
        }
    }
}
