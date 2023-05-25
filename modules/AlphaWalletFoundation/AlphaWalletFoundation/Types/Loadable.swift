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

    public func zip<T2, F2>(_ other: Loadable<T2, F2>) -> Loadable<(T, T2), F> where F == F2 {
        if let selfData = value, let otherData = other.value {
            return Loadable<(T, T2), F>.done((selfData, otherData))
        }

        switch self {
        case .failure(let error): return .failure(error)
        default: ()
        }

        switch other {
        case .failure(let error): return .failure(error)
        default: ()
        }

        return .loading
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
