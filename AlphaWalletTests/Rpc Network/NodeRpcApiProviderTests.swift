//
//  NodeRpcApiProviderTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 21.12.2022.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation
import Combine

class NodeRpcApiProviderTestCase: XCTestCase {
    private let networkService = FakeRpcNetworkService()
    private let rpcUrls = [URL(string: "http://google.com"), URL(string: "http://google.sub1.com"), URL(string: "http://google.sub2.com")].compactMap { $0 }
    private lazy var provider = HttpRpcRequestTransporter(
        server: .main,
        rpcHttpParams: .init(rpcUrls: rpcUrls, headers: [:]),
        networkService: networkService,
        analytics: FakeAnalyticsService())

    private var cancellable = Set<AnyCancellable>()

    private enum AnyRpcError: Error {
        case error1
        case error2
        case error3
    }

    func testSwitchRpcUrlWithFailureCompletionForPublisher() {
        let expectation = XCTestExpectation(description: "wait for node rpc provider failure response")

        let expectation0 = XCTestExpectation(description: "calls initial rpc url")
        let expectation1 = XCTestExpectation(description: "calls next rpc url")
        let expectation2 = XCTestExpectation(description: "calls next rpc url")
        let expectation3 = XCTestExpectation(description: "calls initial rpc url again")

        provider.shouldUseNextRpc = { error in
            switch error {
            case .responseError(let error):
                guard let e = error as? AnyRpcError else { return false }
                return e == .error1
            case .connectionError, .requestError:
                return false
            }
        }

        var call: Int = 0
        networkService.responseClosure = { request in
            let _call = call
            call += 1

            switch _call {
            case 0:
                if request.urlRequest?.url == self.rpcUrls[_call] {
                    expectation0.fulfill()
                }
                return .failure(.responseError(AnyRpcError.error1))
            case 1:
                if request.urlRequest?.url == self.rpcUrls[_call] {
                    expectation1.fulfill()
                }
                return .failure(.responseError(AnyRpcError.error1))
            case 2:
                if request.urlRequest?.url == self.rpcUrls[_call] {
                    expectation2.fulfill()
                }
                return .failure(.responseError(AnyRpcError.error1))
            case 3:
                if request.urlRequest?.url == self.rpcUrls[0] {
                    expectation3.fulfill()
                }
                return .failure(.responseError(AnyRpcError.error2))
            default:
                return .success((data: Data(), response: HTTPURLResponse()))
            }
        }

        provider
            .dataTaskPublisher(.fakeBlockNumber())
            .sink(receiveCompletion: { result in
                guard case .failure = result else { return }
                expectation.fulfill()
            }, receiveValue: { _ in

            }).store(in: &cancellable)

        wait(for: [expectation0, expectation1, expectation2, expectation3, expectation], timeout: 30.0)
    }

    func testCancellation() {
        let expectation = XCTestExpectation(description: "wait for node rpc provider failure response")

        provider.shouldUseNextRpc = { error in
            switch error {
            case .responseError(let error):
                guard let e = error as? AnyRpcError else { return false }
                return e == .error1
            case .connectionError, .requestError:
                return false
            }
        }

        var responseCount: Int = 0
        
        networkService.responseClosure = { _ in
            let _responseCount = responseCount
            responseCount += 1

            switch _responseCount {
            case 0, 1:
                return .failure(.responseError(AnyRpcError.error1))
            case 2:
                return .failure(.responseError(AnyRpcError.error1))
            case 3:
                return .failure(.responseError(AnyRpcError.error2))
            default:
                return .success((data: Data(), response: HTTPURLResponse()))
            }
        }

        networkService.delay = 1

        let cancellable = provider
            .dataTaskPublisher(.fakeBlockNumber())
            .sink(receiveCompletion: { result in
                guard case .failure = result else { return }
            }, receiveValue: { _ in

            })

        cancellable.store(in: &self.cancellable)

        //cancel in 1 sec
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [networkService] in
            cancellable.cancel()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                XCTAssertEqual(responseCount, 1, "should be only one response, this period of time")
                XCTAssertEqual(networkService.calls, 2, "should be only 2 calls, this period of time")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 30.0)
    }
}
