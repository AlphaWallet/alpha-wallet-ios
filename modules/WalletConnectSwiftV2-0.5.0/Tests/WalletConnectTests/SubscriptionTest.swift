

import Foundation
import XCTest
import TestingUtils
@testable import WalletConnect

class WCSubscriberTest: XCTestCase {
    var relay: MockedWCRelay!
    var subscriber: WCSubscriber!
    override func setUp() {
        relay = MockedWCRelay()
        subscriber = WCSubscriber(relay: relay, logger: ConsoleLoggerMock())
    }

    override func tearDown() {
        relay = nil
        subscriber = nil
    }
    
    func testSetGetSubscription() {
        let topic = "1234"
        subscriber.setSubscription(topic: topic)
        XCTAssertFalse(subscriber.getTopics().isEmpty)
        XCTAssertTrue(relay.didCallSubscribe)
    }
    
    func testRemoveSubscription() {
        let topic = "1234"
        subscriber.setSubscription(topic: topic)
        subscriber.removeSubscription(topic: topic)
        XCTAssertTrue(subscriber.getTopics().isEmpty)
        XCTAssertTrue(relay.didCallUnsubscribe)
    }
    
    func testSubscriberPassesPayloadOnSubscribedEvent() {
        let subscriptionExpectation = expectation(description: "onSubscription callback executed")
        let topic = "1234"
        subscriber.setSubscription(topic: topic)
        subscriber.onReceivePayload = { _ in
            subscriptionExpectation.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.01)
        relay.sendSubscriptionPayloadOn(topic: topic)
        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func testSubscriberNotPassesPayloadOnNotSubscribedEvent() {
        let topic = "1234"
        subscriber.setSubscription(topic: topic)
        var onPayloadCalled = false
        subscriber.onReceivePayload = { _ in
            onPayloadCalled = true
        }
        relay.sendSubscriptionPayloadOn(topic: "434241")
        XCTAssertFalse(onPayloadCalled)
    }
}
