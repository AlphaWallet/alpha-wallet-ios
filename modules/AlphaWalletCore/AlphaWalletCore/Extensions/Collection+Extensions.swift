// Copyright © 2023 Stormbird PTE. LTD.

extension Optional where Wrapped: Collection {
    public var isEmpty: Bool {
        switch self {
        case .none:
            return true
        case .some(let value):
            return value.isEmpty
        }
    }
}
