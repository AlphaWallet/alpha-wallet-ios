
import Foundation
import Combine
import XCTest
import WalletConnectUtils
import TestingUtils
@testable import Relayer

final class RelayerEndToEndTests: XCTestCase {
    
    let relayHost = "relay.dev.walletconnect.com"
    let projectId = "52af113ee0c1e1a20f4995730196c13e"
    private var publishers = [AnyCancellable]()
    
    func makeRelayer() -> Relayer {
        let logger = ConsoleLogger()
        let socketConnectionObserver = SocketConnectionObserver()
        let urlSession = URLSession(configuration: .default, delegate: socketConnectionObserver, delegateQueue: OperationQueue())
        let url = Relayer.makeRelayUrl(host: relayHost, projectId: projectId)
        let socket = WebSocketSession(session: urlSession, url: url)
        let dispatcher = Dispatcher(socket: socket, socketConnectionObserver: socketConnectionObserver, socketConnectionHandler: ManualSocketConnectionHandler(socket: socket))
        return Relayer(dispatcher: dispatcher, logger: logger, keyValueStorage: RuntimeKeyValueStorage())
    }
    
    func testSubscribe() {
        let relayer = makeRelayer()
        try! relayer.connect()
        let subscribeExpectation = expectation(description: "subscribe call succeeds")
        relayer.subscribe(topic: "qwerty") { error in
            XCTAssertNil(error)
            subscribeExpectation.fulfill()
        }
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testEndToEndPayload() {
        let relayA = makeRelayer()
        let relayB = makeRelayer()
        try! relayA.connect()
        try! relayB.connect()

        let randomTopic = String.randomTopic()
        let payloadA = "A"
        let payloadB = "B"
        var subscriptionATopic: String!
        var subscriptionBTopic: String!
        var subscriptionAPayload: String!
        var subscriptionBPayload: String!

        let expectation = expectation(description: "publish payloads send and receive successfuly")
        expectation.expectedFulfillmentCount = 2
        
        //TODO -remove this line when request rebound is resolved
        expectation.assertForOverFulfill = false

        relayA.onMessage = { topic, payload in
            (subscriptionATopic, subscriptionAPayload) = (topic, payload)
            expectation.fulfill()
        }
        relayB.onMessage = { topic, payload in
            (subscriptionBTopic, subscriptionBPayload) = (topic, payload)
            expectation.fulfill()
        }
        relayA.publish(topic: randomTopic, payload: payloadA) { error in
            XCTAssertNil(error)
        }
        relayB.publish(topic: randomTopic, payload: payloadB) { error in
            XCTAssertNil(error)
        }
        relayA.subscribe(topic: randomTopic) { error in
            XCTAssertNil(error)
        }
        relayB.subscribe(topic: randomTopic) { error in
            XCTAssertNil(error)
        }

        waitForExpectations(timeout: defaultTimeout, handler: nil)
        XCTAssertEqual(subscriptionATopic, randomTopic)
        XCTAssertEqual(subscriptionBTopic, randomTopic)
        
        //TODO - uncomment lines when request rebound is resolved
//        XCTAssertEqual(subscriptionBPayload, payloadA)
//        XCTAssertEqual(subscriptionAPayload, payloadB)
    }
}
