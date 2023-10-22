// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }

    func asyncCompactMap<T>(_ transform: (Self.Element) async throws -> T?) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            if let result = try await transform(element) {
                values.append(result)
            }
        }
        return values
    }

    func asyncFlatMap<T: Sequence>(_ transform: (Element) async throws -> T) async rethrows -> [T.Element] {
        var values = [T.Element]()
        for element in self {
            try await values.append(contentsOf: transform(element))
        }
        return values
    }

    func asyncContains(where predicate: (Self.Element) async throws -> Bool) async rethrows -> Bool {
        for element in self where try await predicate(element) {
            return true
        }
        return false
    }
}