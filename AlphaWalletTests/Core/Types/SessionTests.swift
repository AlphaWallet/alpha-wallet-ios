//
//  SessionTests.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import XCTest
import Foundation
import Combine
@testable import AlphaWallet
import AlphaWalletFoundation

class SessionTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()
    private let networkService = FakeRpcNetworkService()
    private lazy var provider = HttpRpcRequestTransporter.make(
        server: .main,
        rpcHttpParams: .init(rpcUrls: [rpcUrl], headers: [:]),
        networkService: networkService)
    private let rpcUrl = URL(string: "http//:google.com")!
    func testSessionDefaultRetries() throws {
        let callCompletionExpectation = self.expectation(description: "expect to call callback closure after few retries")

        networkService.callbackQueue = .main
        networkService.delay = 1
        networkService.responseClosure = { _ in
            return .failure(.requestError(RpcNodeRetryableRequestError.networkConnectionWasLost))
        }
//        provider.retryBehavior = { _ in
//            return .immediate(retries: 2)
//        }
//        provider.retries = 2

        provider
            .dataTaskPublisher(.fakeBlockNumber())
            .replaceError(with: .init(errorWithoutID: .internalError))
            .eraseToAnyPublisher()
            .sink { [networkService] _ in
                callCompletionExpectation.fulfill()
                XCTAssertEqual(networkService.calls, 3)
            }.store(in: &cancelable)

        waitForExpectations(timeout: 50)
    }

    func testSessionRetry() throws {
        let callCompletionExpectation = self.expectation(description: "expect to call callback closure after few retries")

        networkService.callbackQueue = .main
        networkService.delay = 1
        networkService.responseClosure = { _ in
            return .failure(.requestError(RpcNodeRetryableRequestError.networkConnectionWasLost))
        }

//        provider.retries = 3
//        provider.retryBehavior = { _ in
//            return .immediate(retries: 3)
//        }

        provider
            .dataTaskPublisher(.fakeBlockNumber())
            .replaceError(with: .init(errorWithoutID: .internalError))
            .eraseToAnyPublisher()
            .sink { [networkService] _ in
                callCompletionExpectation.fulfill()
                XCTAssertEqual(networkService.calls, 4)
            }.store(in: &cancelable)

        waitForExpectations(timeout: 10)
    }

    func testSessionCancel() throws {
        let failureExpectation = self.expectation(description: "expect to call callback closure after when call canceled")

        networkService.callbackQueue = .main
        networkService.delay = 2
        networkService.responseClosure = { _ in
            return .failure(.requestError(RpcNodeRetryableRequestError.rateLimited(server: .main, domainName: "")))
        }

//        provider.retries = 3
//        provider.retryBehavior = { _ in
//            return .immediate(retries: 3)
//        }

        let cancelable = provider
            .dataTaskPublisher(.fakeBlockNumber())
            .eraseToAnyPublisher()
            .sink(receiveCompletion: { _ in
                //no-op
            }, receiveValue: { _ in
                //no-op
            })

        cancelable.store(in: &self.cancelable)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [networkService] in
            cancelable.cancel()
            failureExpectation.fulfill()
            XCTAssertEqual(networkService.calls, 1)
        }

        waitForExpectations(timeout: 10)
    }

}

extension RpcRequest {
    static func fakeBlockNumber() -> RpcRequest {
        RpcRequest(method: "fake_blockNumber")
    }
}
