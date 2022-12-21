//
//  SessionTests.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import XCTest
import Foundation
import Combine
import PromiseKit
@testable import AlphaWallet
import AlphaWalletFoundation
import JSONRPCKit

class SessionTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()
    private let networkService = FakeNetworkService()
    private lazy var provider = BaseRpcApiProvider.make(networkService: networkService)

    func testSessionDefaultRetries() throws {
        let callCompletionExpectation = self.expectation(description: "expect to call callback closure after few retries")

        networkService.callbackQueue = .main
        networkService.delay = 1
        networkService.responseClosure = { _ in
            return .failure(.requestError(RpcNodeRetryableRequestError.networkConnectionWasLost))
        }

        provider.retries = 2

        provider
            .dataTaskPublisher(JsonRpcRequest(server: .main, request: FakeBlockNumberRequest()))
            .replaceError(with: .zero)
            .eraseToAnyPublisher()
            .sink { [networkService] _ in
                callCompletionExpectation.fulfill()
                XCTAssertEqual(networkService.calls, 3)
            }.store(in: &cancelable)

        waitForExpectations(timeout: 10)
    }

    func testSessionRetry() throws {
        let callCompletionExpectation = self.expectation(description: "expect to call callback closure after few retries")

        networkService.callbackQueue = .main
        networkService.delay = 1
        networkService.responseClosure = { _ in
            return .failure(.requestError(RpcNodeRetryableRequestError.networkConnectionWasLost))
        }

        provider.retries = 3

        provider
            .dataTaskPublisher(JsonRpcRequest(server: .main, request: FakeBlockNumberRequest()))
            .replaceError(with: .zero)
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

        provider.retries = 3

        let cancelable = provider
            .dataTaskPublisher(JsonRpcRequest(server: .main, request: FakeBlockNumberRequest()))
            .print("xxx.dataTaskPublisher")
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

import BigInt
struct FakeBlockNumberRequest: JSONRPCKit.Request {
    public typealias Response = BigInt

    public init() { }

    public var method: String {
        return "fake_blockNumber"
    }

    public func response(from resultObject: Any) throws -> Response {
        if let response = resultObject as? String, let value = BigInt(response.drop0x, radix: 16) {
            return numericCast(value)
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}
