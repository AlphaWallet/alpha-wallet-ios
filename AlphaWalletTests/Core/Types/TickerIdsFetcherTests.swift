//
//  TickerIdsFetcherTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 19.07.2022.
//

import XCTest
import Foundation
import Combine
@testable import AlphaWallet
import AlphaWalletFoundation

class FakeTickerIdsFetcher: TickerIdsFetcher {
    private let subject: AnyPublisher<TickerIdString?, Never>
    private var cancelable = Set<AnyCancellable>()

    init(subject: AnyPublisher<TickerIdString?, Never>) {
        self.subject = subject
    }

    func tickerId(for token: AlphaWalletFoundation.TokenMappedToTicker) async -> TickerIdString? {
        return await withCheckedContinuation { continuation in
            subject.sink(receiveValue: { tickerIdString in
                continuation.resume(with: .success(tickerIdString))
            }).store(in: &cancelable)
        }
    }
}

class TickerIdsFetcherTests: XCTestCase {
    var cancelable = Set<AnyCancellable>()

    func testExample() async throws {
        let s1 = PassthroughSubject<TickerIdString?, Never>()
        let f1 = FakeTickerIdsFetcher(subject: s1.eraseToAnyPublisher())
        let f2 = FakeTickerIdsFetcher(subject: .just(nil))
        let f3 = FakeTickerIdsFetcher(subject: .just("3"))

        let fetcher = TickerIdsFetcherImpl(providers: [f2, f1, f3])
        let expectation = self.expectation(description: "Wait for ticker id to be resolved")

        Task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                s1.send("1")
                s1.send(completion: .finished)
            }

            let tickerId = await fetcher.tickerId(for: TokenMappedToTicker(token: Token()))
            XCTAssertEqual(tickerId, "1")
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
    }
}
