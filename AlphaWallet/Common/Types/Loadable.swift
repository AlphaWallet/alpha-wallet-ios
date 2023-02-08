// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

enum Loadable<T, F> {
    case loading
    case done(T)
    case failure(F)
}

extension Loadable: Equatable where T: Equatable, F: Equatable {
    static func == (lhs: Loadable<T, F>, rhs: Loadable<T, F>) -> Bool {
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
