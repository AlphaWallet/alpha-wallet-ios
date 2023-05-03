//
//  OneinchTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 19.09.2022.
//

import XCTest
@testable import AlphaWalletFoundation
import Combine
import CombineExt
import AlphaWalletCore
import AlphaWalletLogger

final class OneinchTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()

    func testOneinch() {
        let reachability: ReachabilityManagerProtocol = FakeReachabilityManager(true)

        let networking = FakeBaseOneinchNetworking()
        let retries: UInt = 3
        let retryBehavior: RetryBehavior<RunLoop> = .randomDelayed(retries: retries, delayBeforeRetry: 1, delayUpperRangeValueFrom0To: 3)
        let oneinch = Oneinch(action: "Buy with Oneinch", networking: networking, reachability: reachability, retryBehavior: retryBehavior)
        infoLog("[Oneinch] Start")
        oneinch.start()

        let expectation = self.expectation(description: "Wait for failure")
        oneinch.objectWillChange.sink { [weak oneinch, networking] _ in
            infoLog("[Oneinch] objectWillChange")
            guard let oneinch = oneinch else { return XCTFail() }
            guard case .loading = oneinch.assets else { return XCTFail() }
            expectation.fulfill()
            XCTAssertTrue(networking.asyncAPICallCount == retries + 1)
        }.store(in: &cancelable)

        waitForExpectations(timeout: 60)
    }

    final class FakeBaseOneinchNetworking: OneinchNetworking {
        let msTimeFormatter: DateFormatter = {
            let msTimeFormatter = DateFormatter()
            msTimeFormatter.dateFormat = "[HH:mm:ss.SSSS] "

            return msTimeFormatter
        }()
        var asyncAPICallCount = 0
        var futureClosureHandlerCount = 0

        private func instrumentedAsyncAPICall(sabotage: Bool, completion completionBlock: @escaping ((Bool, PromiseError?) -> Void)) {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(Int.random(in: 1 ... 3))) {
                self.asyncAPICallCount += 1
                infoLog("[Oneinch] " + self.msTimeFormatter.string(from: Date()) + " * completing async call ")
                if sabotage {
                    completionBlock(false, .some(error: TestFailureCondition.invalidServerResponse))
                } else {
                    completionBlock(true, nil)
                }
            }
        }

        enum TestFailureCondition: Error {
            case invalidServerResponse
        }

        func retrieveAssets() -> AnyPublisher<[AlphaWalletFoundation.Oneinch.Asset], AlphaWalletCore.PromiseError> {
            return Deferred {
                Future<[AlphaWalletFoundation.Oneinch.Asset], PromiseError> { promise in
                    self.futureClosureHandlerCount += 1
                    // setting "sabotage: true" in the asyncAPICall tells the test code to return a
                    // failure result, which will illustrate "retry" better.
                    self.instrumentedAsyncAPICall(sabotage: true) { _, err in
                        // NOTE(heckj): the closure resolving the API call into a Promise result
                        // is called far more than 3 times - 5 in this example, although I don't know
                        // why that is. The underlying API call, and the closure within the future
                        // are each called 3 times - validated below in the assertions.
                        if let err = err {
                            return promise(.failure(err))
                        }
                        return promise(.success([]))
                    }
                }
            }.eraseToAnyPublisher()
        }
    }
}
