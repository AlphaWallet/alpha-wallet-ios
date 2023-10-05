// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import APIKit

public protocol BlockchainCallable {
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError>
    func callAsync<R: ContractMethodCall>(_ method: R, block: BlockParameter) async throws -> R.Response
}

public extension BlockchainCallable {
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter = .latest) -> AnyPublisher<R.Response, SessionTaskError> {
        call(method, block: block)
    }

    func callAsync<R: ContractMethodCall>(_ method: R, block: BlockParameter = .latest) async throws -> R.Response {
        try await callAsync(method, block: block)
    }
}
