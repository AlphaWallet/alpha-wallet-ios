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

extension APIKitSession {
    typealias SendPublisherExampleClosure = (_ callback: @escaping(SessionTaskError?) -> Void) -> Void

    class func sendPublisherTestsOnly(closure: @escaping SendPublisherExampleClosure) -> AnyPublisher<Void, SessionTaskError> {
        var isCanceled: Bool = false
        let publisher = Deferred {
            Future<Void, SessionTaskError> { seal in
                closure { error in
                    guard !isCanceled else { return }
                    if let error = error {
                        let server = RPCServer.main
                        if let e = convertToUserFriendlyError(error: error, server: server, baseUrl: URL(string: "http:/google.com")!) {
                            seal(.failure(.requestError(e)))
                        } else {
                            seal(.failure(error))
                        }
                    } else {
                        seal(.success(()))
                    }
                }
            }
        }.handleEvents(receiveCancel: {
            isCanceled = true
        })

        return publisher
            .eraseToAnyPublisher()
    }
}

class SessionTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()

    func testSessionRetry() throws {
        var callbackCallCounter: Int = 0
        let callCompletionExpectation = self.expectation(description: "expect to call callback closure after few retries")

        let testExampleClosure: APIKitSession.SendPublisherExampleClosure = { closure in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                closure(.requestError(RpcNodeRetryableRequestError.networkConnectionWasLost))
            }
            callbackCallCounter += 1
        }

        APIKitSession.sendPublisherTestsOnly(closure: testExampleClosure)
            .retry(times: 2, when: {
                guard case SessionTaskError.requestError(let e) = $0 else { return false }
                return e is RpcNodeRetryableRequestError
            })
            .replaceError(with: ())
            .eraseToAnyPublisher()
            .sink { _ in
                callCompletionExpectation.fulfill()
                XCTAssertEqual(callbackCallCounter, 3)
            }.store(in: &cancelable)

        waitForExpectations(timeout: 10)
    }

    func testSessionCancel() throws {
        var retryCallbackCallCounter: Int = 0
        let failureExpectation = self.expectation(description: "expect to call callback closure after when call canceled")

        let testExampleClosure: APIKitSession.SendPublisherExampleClosure = { closure in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                closure(.requestError(RpcNodeRetryableRequestError.networkConnectionWasLost))
            }
        }

        let publisher = APIKitSession.sendPublisherTestsOnly(closure: testExampleClosure)
        let cancelable = publisher
            .retry(times: 2, when: {
                retryCallbackCallCounter += 1
                guard case SessionTaskError.requestError(let e) = $0 else { return false }
                return e is RpcNodeRetryableRequestError
            })
            .eraseToAnyPublisher()
            .sink(receiveCompletion: { _ in
                //no-op
            }, receiveValue: { _ in
                //no-op
            })

        cancelable.store(in: &self.cancelable)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            cancelable.cancel()
            failureExpectation.fulfill()
            XCTAssertEqual(retryCallbackCallCounter, 1)
        }

        waitForExpectations(timeout: 3)
    }

}
