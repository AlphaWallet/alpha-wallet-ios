//
//  RetryPublisherTests.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.05.2022.
//

import Combine
import XCTest
import AlphaWalletAddress
import AlphaWalletCore
@testable import AlphaWallet
import AlphaWalletFoundation
import AlphaWalletLogger

class RetryPublisherTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()

    enum TestFailureCondition: Error {
        case invalidServerResponse
    }

    func testRetryOperatorWithPassthroughSubject() {
        let simpleControlledPublisher = PassthroughSubject<String, Error>()

        let cancellable = simpleControlledPublisher
            .retry(1)
            .sink(receiveCompletion: { fini in
                infoLog(" ** .sink() received the completion: \(String(describing: fini))")
            }, receiveValue: { stringValue in
                XCTAssertNotNil(stringValue)
                infoLog(" ** .sink() received \(stringValue)")
            })

        let oneFish = "onefish"
        let twoFish = "twofish"
        let redFish = "redfish"
        let blueFish = "bluefish"

        simpleControlledPublisher.send(oneFish)
        simpleControlledPublisher.send(twoFish)

        simpleControlledPublisher.send(completion: Subscribers.Completion.failure(TestFailureCondition.invalidServerResponse))

        simpleControlledPublisher.send(redFish)
        simpleControlledPublisher.send(blueFish)
        XCTAssertNotNil(cancellable)
    }

    func testRetryOperatorWithCurrentValueSubject() {
        let simpleControlledPublisher = CurrentValueSubject<String, Error>("initial value")

        let cancellable = simpleControlledPublisher
            .retry(3)
            .sink(receiveCompletion: { fini in
                infoLog(" ** .sink() received the completion: \(String(describing: fini))")
            }, receiveValue: { stringValue in
                XCTAssertNotNil(stringValue)
                infoLog(" ** .sink() received \(stringValue)")
            })

        let oneFish = "onefish"

        simpleControlledPublisher.send(oneFish)
        simpleControlledPublisher.send(completion: Subscribers.Completion.failure(TestFailureCondition.invalidServerResponse))
        XCTAssertNotNil(cancellable)
    }

    func testRetryWithOneShotJustPublisher() {
        let cancellable = Just<String>("yo")
            .retry(3)
            .sink(receiveCompletion: { fini in
                infoLog(" ** .sink() received the completion: \(String(describing: fini))")
            }, receiveValue: { stringValue in
                XCTAssertNotNil(stringValue)
                infoLog(" ** .sink() received \(stringValue)")
            })
        XCTAssertNotNil(cancellable)
    }

    func testRetryWithOneShotFailPublisher() {
        let cancellable = Fail(outputType: String.self, failure: TestFailureCondition.invalidServerResponse)
            .retry(3)
            .sink(receiveCompletion: { fini in
                infoLog(" ** .sink() received the completion: \(String(describing: fini))")
            }, receiveValue: { stringValue in
                XCTAssertNotNil(stringValue)
                infoLog(" ** .sink() received \(stringValue)")
            })
        XCTAssertNotNil(cancellable)
    }

    func testRetryDelayOnFailureOnly() {
        let expectation = XCTestExpectation(description: debugDescription)
        var asyncAPICallCount = 0
        var futureClosureHandlerCount = 0

        let msTimeFormatter = DateFormatter()
        msTimeFormatter.dateFormat = "[HH:mm:ss.SSSS] "

        func instrumentedAsyncAPICall(sabotage: Bool, completion completionBlock: @escaping ((Bool, Error?) -> Void)) {
            DispatchQueue.global(qos: .background).async {
                let delay = Int.random(in: 1 ... 3)
                infoLog(msTimeFormatter.string(from: Date()) + " * starting async call (waiting \(delay) seconds before returning) ")
                asyncAPICallCount += 1
                sleep(UInt32(delay))
                infoLog(msTimeFormatter.string(from: Date()) + " * completing async call ")
                if sabotage {
                    completionBlock(false, TestFailureCondition.invalidServerResponse)
                } else {
                    completionBlock(true, nil)
                }
            }
        }

        let upstreamPublisher = Deferred {
            Future<String, Error> { promise in
                futureClosureHandlerCount += 1
                instrumentedAsyncAPICall(sabotage: true) { _, err in
                    if let err = err {
                        return promise(.failure(err))
                    }
                    return promise(.success("allowed!"))
                }
            }
        }.eraseToAnyPublisher()

        let resultPublisher = upstreamPublisher.catch { _ -> AnyPublisher<String, Error> in
            infoLog(msTimeFormatter.string(from: Date()) + "delaying on error for ~3 seconds ")
            return Publishers.Delay(upstream: upstreamPublisher,
                                    interval: 3,
                                    tolerance: 1,
                                    scheduler: DispatchQueue.global())
                .retry(2)
                .eraseToAnyPublisher()
        }

        XCTAssertEqual(asyncAPICallCount, 0)
        XCTAssertEqual(futureClosureHandlerCount, 0)

        let cancellable = resultPublisher.sink(receiveCompletion: { err in
            infoLog(msTimeFormatter.string(from: Date()) + ".sink() received the completion: \(String(describing: err))")
            XCTAssertEqual(asyncAPICallCount, 4)
            XCTAssertEqual(futureClosureHandlerCount, 4)
            expectation.fulfill()
        }, receiveValue: { value in
            infoLog(".sink() received value: \(value)")
            XCTFail("no value should be returned")
        })

        wait(for: [expectation], timeout: 30.0)
        XCTAssertNotNil(cancellable)
    }

    func testRetryWithRandomDelay() {
        let expectation = XCTestExpectation(description: debugDescription)
        var asyncAPICallCount = 0
        var futureClosureHandlerCount = 0
        let msTimeFormatter = DateFormatter()
        msTimeFormatter.dateFormat = "[HH:mm:ss.SSSS] "

        func instrumentedAsyncAPICall(sabotage: Bool, completion completionBlock: @escaping ((Bool, Error?) -> Void)) {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(Int.random(in: 1 ... 3))) {
                asyncAPICallCount += 1
                infoLog(msTimeFormatter.string(from: Date()) + " * completing async call ")
                if sabotage {
                    completionBlock(false, TestFailureCondition.invalidServerResponse)
                } else {
                    completionBlock(true, nil)
                }
            }
        }

        let upstreamPublisher = Deferred {
            return Future<String, Error> { promise in
                futureClosureHandlerCount += 1
                instrumentedAsyncAPICall(sabotage: true) { _, err in
                    if let err = err {
                        return promise(.failure(err))
                    }
                    return promise(.success("allowed!"))
                }
            }
        }

        let resultPublisher = upstreamPublisher.retry(.randomDelayed(retries: 2, delayBeforeRetry: 2, delayUpperRangeValueFrom0To: 5), scheduler: DispatchQueue.global(qos: .userInitiated))
        XCTAssertEqual(asyncAPICallCount, 0)
        XCTAssertEqual(futureClosureHandlerCount, 0)

        resultPublisher.sink(receiveCompletion: { err in
            infoLog(msTimeFormatter.string(from: Date()) + ".sink() received the completion: \(String(describing: err))")
            XCTAssertEqual(asyncAPICallCount, 3)
            XCTAssertEqual(futureClosureHandlerCount, 3)
            expectation.fulfill()
        }, receiveValue: { value in
            infoLog(".sink() received value: \(value)")
            XCTFail("no value should be returned")
        }).store(in: &cancelable)

        wait(for: [expectation], timeout: 500.0)
    }

    func testRetryWithRandomDelay2() {
        let expectation = XCTestExpectation(description: debugDescription)
        var asyncAPICallCount = 0
        var futureClosureHandlerCount = 0

        let msTimeFormatter = DateFormatter()
        msTimeFormatter.dateFormat = "[HH:mm:ss.SSSS] "

        func instrumentedAsyncAPICall(sabotage: Bool, completion completionBlock: @escaping ((Bool, Error?) -> Void)) {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(Int.random(in: 1 ... 3))) {
                asyncAPICallCount += 1
                infoLog(msTimeFormatter.string(from: Date()) + " * completing async call ")
                if sabotage {
                    completionBlock(false, TestFailureCondition.invalidServerResponse)
                } else {
                    completionBlock(true, nil)
                }
            }
        }

        let upstreamPublisher = Deferred {
            return Future<String, Error> { promise in
                futureClosureHandlerCount += 1
                instrumentedAsyncAPICall(sabotage: true) { _, err in
                    if let err = err {
                        return promise(.failure(err))
                    }
                    return promise(.success("allowed!"))
                }
            }
        }

        let resultPublisher = upstreamPublisher.retry(.custom(retries: 2, delayCalculator: { _ in
            return TimeInterval(Int.random(in: 5 ... 8))
        }), scheduler: DispatchQueue.global(qos: .userInitiated))

        XCTAssertEqual(asyncAPICallCount, 0)
        XCTAssertEqual(futureClosureHandlerCount, 0)

        resultPublisher.sink(receiveCompletion: { err in
            infoLog(msTimeFormatter.string(from: Date()) + ".sink() received the completion: \(String(describing: err))")
            XCTAssertEqual(asyncAPICallCount, 3)
            XCTAssertEqual(futureClosureHandlerCount, 3)
            expectation.fulfill()
        }, receiveValue: { value in
            infoLog(".sink() received value: \(value)")
            XCTFail("no value should be returned")
        }).store(in: &cancelable)

        wait(for: [expectation], timeout: 500.0)
    }

    func testRetryWithoutDelay() {
        let expectation = XCTestExpectation(description: debugDescription)
        var asyncAPICallCount = 0
        var futureClosureHandlerCount = 0

        let msTimeFormatter = DateFormatter()
        msTimeFormatter.dateFormat = "[HH:mm:ss.SSSS] "

        func instrumentedAsyncAPICall(sabotage: Bool, completion completionBlock: @escaping ((Bool, Error?) -> Void)) {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + .seconds(Int.random(in: 1 ... 3))) {
                asyncAPICallCount += 1
                infoLog(msTimeFormatter.string(from: Date()) + " * completing async call ")
                if sabotage {
                    completionBlock(false, TestFailureCondition.invalidServerResponse)
                } else {
                    completionBlock(true, nil)
                }
            }
        }

        let upstreamPublisher = Deferred {
            return Future<String, Error> { promise in
                futureClosureHandlerCount += 1
                instrumentedAsyncAPICall(sabotage: true) { _, err in
                    if let err = err {
                        return promise(.failure(err))
                    }
                    return promise(.success("allowed!"))
                }
            }
        }
        let resultPublisher = upstreamPublisher.retry(.immediate(retries: 2), scheduler: DispatchQueue.global())

        XCTAssertEqual(asyncAPICallCount, 0)
        XCTAssertEqual(futureClosureHandlerCount, 0)

        resultPublisher.sink(receiveCompletion: { err in
            infoLog(msTimeFormatter.string(from: Date()) + ".sink() received the completion: \(String(describing: err))")
            XCTAssertEqual(asyncAPICallCount, 3)
            XCTAssertEqual(futureClosureHandlerCount, 3)
            expectation.fulfill()
        }, receiveValue: { value in
            infoLog(".sink() received value: \(value)")
            XCTFail("no value should be returned")
        }).store(in: &cancelable)

        wait(for: [expectation], timeout: 50.0)
    }
}
