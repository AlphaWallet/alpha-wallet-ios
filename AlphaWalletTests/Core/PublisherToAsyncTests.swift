//
//  PublisherToAsyncTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 22.03.2023.
//

import XCTest
@testable import AlphaWallet
import Foundation
import AlphaWalletFoundation
import Combine

class PublisherToAsyncTests: XCTestCase {

    func testAsyncValues() {
        let expectation = self.expectation(description: "")
        let publisher = AnyPublisher<Int, Never>.create { seal in
            for each in 0...10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    seal.send(each)
                    if each == 9 {
                        seal.send(completion: .finished)
                    }
                }
            }

            return AnyCancellable { }
        }

        Task {
            for try await _ in publisher.values {
                //no-op
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testAsyncValuesCancellation() {
        let expectation = self.expectation(description: "")
        let publisher = AnyPublisher<Int, Never>.create { seal in
            for each in 0...10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    seal.send(each)

                    if each == 9 {
                        seal.send(completion: .finished)
                    }
                }
            }

            return AnyCancellable {

            }
        }.handleEvents(receiveCancel: { expectation.fulfill() })

        let task = Task {
            for try await _ in publisher.values {
                //no-op
            }
        }

        DispatchQueue.main.async {
            task.cancel()
        }

        waitForExpectations(timeout: 10)
    }
}
