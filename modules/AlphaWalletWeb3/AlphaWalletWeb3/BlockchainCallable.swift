// Copyright © 2023 Stormbird PTE. LTD.

import Combine

public protocol BlockchainCallable {
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter) -> AnyPublisher<R.Response, SessionTaskError>
}

public extension BlockchainCallable {
    func call<R: ContractMethodCall>(_ method: R, block: BlockParameter = .latest) -> AnyPublisher<R.Response, SessionTaskError> {
        call(method, block: block)
    }
}
