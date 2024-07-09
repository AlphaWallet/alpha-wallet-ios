// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public extension Sequence {
    func asyncMap<T>(_ transform: @escaping (Element) async throws -> T) async rethrows -> [T] {
        return try await withThrowingTaskGroup( of: T.self) { [self] group in
            for element in self {
                group.addTask { try await transform(element) }
            }
            var values = [T]()
            for try await result in group {
                values.append(result)
            }
            return values
        }
    }

    func asyncCompactMap<T>(_ transform: @escaping (Element) async throws -> T?) async rethrows -> [T] {
        return try await withThrowingTaskGroup( of: T?.self) { [self] group in
            for element in self {
                group.addTask { try await transform(element) }
            }
            var values = [T]()
            for try await result in group {
                if let result {
                    values.append(result)
                }
            }
            return values
        }
    }

    func asyncFlatMap<T: Sequence>(_ transform: @escaping (Element) async throws -> T) async rethrows -> [T.Element] {
        return try await withThrowingTaskGroup( of: T.self) { [self] group in
            for element in self {
                group.addTask { try await transform(element) }
            }
            var values = [T.Element]()
            for try await result in group {
                values.append(contentsOf: result)
            }
            return values
        }
    }

    func asyncContains(where predicate: (Self.Element) async throws -> Bool) async rethrows -> Bool {
        for element in self where try await predicate(element) {
            return true
        }
        return false
    }
}
