//
//  Task.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 21.03.2023.
//

import Foundation
import Combine

extension Task {
    public func store(in cancellables: inout Set<AnyCancellable>) {
        asCancellable().store(in: &cancellables)
    }

    func asCancellable() -> AnyCancellable {
        .init { self.cancel() }
    }
}

extension Task where Failure == Error {
    @discardableResult static func retrying(priority: TaskPriority? = nil, times maxRetryCount: Int = 3, operation: @Sendable @escaping () async throws -> Success) -> Task {
        Task(priority: priority) {
            for _ in 0..<maxRetryCount {
                try Task<Never, Never>.checkCancellation()
                do {
                    return try await operation()
                } catch {
                    continue
                }
            }
            try Task<Never, Never>.checkCancellation()
            return try await operation()
        }
    }
}