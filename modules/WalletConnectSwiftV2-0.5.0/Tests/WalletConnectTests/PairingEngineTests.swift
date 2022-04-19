import XCTest
@testable import WalletConnect
import TestingUtils
@testable import WalletConnectKMS
import WalletConnectUtils

func deriveTopic(publicKey: String, privateKey: AgreementPrivateKey) -> String {
    try! KeyManagementService.generateAgreementSecret(from: privateKey, peerPublicKey: publicKey).derivedTopic()
}

final class PairingEngineTests: XCTestCase {
    
    var engine: PairingEngine!
    
    var relayMock: MockedWCRelay!
    var subscriberMock: MockedSubscriber!
    var storageMock: PairingSequenceStorageMock!
    var cryptoMock: KeyManagementServiceMock!
    
    var topicGenerator: TopicGenerator!
    
    override func setUp() {
        relayMock = MockedWCRelay()
        subscriberMock = MockedSubscriber()
        storageMock = PairingSequenceStorageMock()
        cryptoMock = KeyManagementServiceMock()
        topicGenerator = TopicGenerator()
    }

    override func tearDown() {
        relayMock = nil
        subscriberMock = nil
        storageMock = nil
        cryptoMock = nil
        topicGenerator = nil
        engine = nil
    }
    
    func setupEngine(isController: Bool) {
        let meta = AppMetadata(name: nil, description: nil, url: nil, icons: nil)
        let logger = ConsoleLoggerMock()
        engine = PairingEngine(
            relay: relayMock,
            kms: cryptoMock,
            subscriber: subscriberMock,
            sequencesStore: storageMock,
            metadata: meta,
            logger: logger,
            topicGenerator: topicGenerator.getTopic)
    }
    
    func testPropose() {
        setupEngine(isController: false)
        
        let topicA = topicGenerator.topic
        let uri = engine.propose(permissions: SessionPermissions.stub())!
        
        XCTAssert(cryptoMock.hasPrivateKey(for: uri.publicKey), "Proposer must store the private key matching the public key sent through the URI.")
        XCTAssert(storageMock.hasPendingProposedPairing(on: topicA), "The engine must store a pending pairing on proposed state.")
        XCTAssert(subscriberMock.didSubscribe(to: topicA), "Proposer must subscribe to topic A to listen for approval message.")
    }
    
    func testApprove() throws {
        setupEngine(isController: true)
        
        let uri = WalletConnectURI.stub()
        let topicA = uri.topic
        let topicB = deriveTopic(publicKey: uri.publicKey, privateKey: cryptoMock.privateKeyStub)

        try engine.approve(uri)

        // The concept of "publish" should only be known by the relayer
        guard let publishTopic = relayMock.requests.first?.topic, let approval = relayMock.requests.first?.request.pairingApproveParams else {
            XCTFail("Responder must publish an approval request."); return
        }

        XCTAssert(subscriberMock.didSubscribe(to: topicA), "Responder must subscribe to topic A to listen for approval request acknowledgement.")
        XCTAssert(subscriberMock.didSubscribe(to: topicB), "Responder must subscribe to topic B to settle the pairing sequence optimistically.")
        XCTAssert(cryptoMock.hasPrivateKey(for: approval.responder.publicKey), "Responder must store the private key matching the public key sent to its peer.")
        XCTAssert(cryptoMock.hasAgreementSecret(for: topicB), "Responder must derive and store the shared secret used to encrypt communication over topic B.")
        XCTAssert(storageMock.hasPendingRespondedPairing(on: topicA), "The engine must store a pending pairing on responded state.")
        XCTAssert(storageMock.hasPreSettledPairing(on: topicB), "The engine must optimistically store a settled pairing on pre-settled state.")
        XCTAssertEqual(publishTopic, topicA, "The approval request must be published over topic A.")
    }
    
    func testApproveMultipleCallsThrottleOnSameURI() {
        setupEngine(isController: true)
        let uri = WalletConnectURI.stub()
        for i in 1...10 {
            if i == 1 {
                XCTAssertNoThrow(try engine.approve(uri))
            } else {
                XCTAssertThrowsError(try engine.approve(uri))
            }
        }
    }
    
    func testApproveAcknowledgement() throws {
        setupEngine(isController: true)
        
        let uri = WalletConnectURI.stub()
        let topicA = uri.topic
        let topicB = deriveTopic(publicKey: uri.publicKey, privateKey: cryptoMock.privateKeyStub)
        var acknowledgedPairing: Pairing?
        engine.onApprovalAcknowledgement = { acknowledgedPairing = $0 }

        try engine.approve(uri)
        let success = JSONRPCResponse<AnyCodable>(id: 0, result: AnyCodable(true))
        let response = WCResponse(topic: topicA, chainId: nil, requestMethod: .pairingApprove, requestParams: .pairingApprove(PairingType.ApprovalParams(relay: RelayProtocolOptions(protocol: "", params: nil), responder: PairingParticipant(publicKey: ""), expiry: 0, state: nil)), result: .response(success))
        relayMock.onPairingResponse?(response)
        
        XCTAssert(storageMock.hasAcknowledgedPairing(on: topicB), "Settled pairing must advance to acknowledged state.")
        XCTAssertFalse(storageMock.hasSequence(forTopic: topicA), "Pending pairing must be deleted.")
        XCTAssert(subscriberMock.didUnsubscribe(to: topicA), "Responder must unsubscribe from topic A after approval acknowledgement.")
        XCTAssertEqual(acknowledgedPairing?.topic, topicB, "The acknowledged pairing must be settled on topic B.")
        // TODO: Assert update call
    }
    
    func testReceiveApprovalResponse() {
        setupEngine(isController: false)
        
        var approvedPairing: Pairing?
        let responderPubKey = AgreementPrivateKey().publicKey.hexRepresentation
        let topicB = deriveTopic(publicKey: responderPubKey, privateKey: cryptoMock.privateKeyStub)
        let uri = engine.propose(permissions: SessionPermissions.stub())!
        let topicA = uri.topic
        
        let approveParams = PairingType.ApprovalParams(
            relay: RelayProtocolOptions(protocol: "", params: nil),
            responder: PairingParticipant(publicKey: responderPubKey),
            expiry: Time.day,
            state: nil)
        let request = WCRequest(method: .pairingApprove, params: .pairingApprove(approveParams))
        let payload = WCRequestSubscriptionPayload(topic: topicA, wcRequest: request)
        
        engine.onPairingApproved = { pairing, _, _ in
            approvedPairing = pairing
        }
        subscriberMock.onReceivePayload?(payload)
        
        XCTAssert(subscriberMock.didUnsubscribe(to: topicA), "Proposer must unsubscribe from topic A after approval acknowledgement.")
        XCTAssert(subscriberMock.didSubscribe(to: topicB), "Proposer must subscribe to topic B to settle for communication with the peer.")
        XCTAssert(cryptoMock.hasPrivateKey(for: uri.publicKey), "Proposer must keep its private key after settlement.")
        XCTAssert(cryptoMock.hasAgreementSecret(for: topicB), "Proposer must derive and store the shared secret used to communicate over topic B.")
        XCTAssert(storageMock.hasAcknowledgedPairing(on: topicB), "The acknowledged pairing must be settled on topic B.")
        XCTAssertFalse(storageMock.hasSequence(forTopic: topicA), "The engine must clean any stored pairing on topic A.")
        XCTAssertNotNil(approvedPairing, "The engine should callback the approved pairing after settlement.")
        XCTAssertEqual(approvedPairing?.topic, topicB, "The approved pairing must settle on topic B.")
        // TODO: Check if expiry time is correct
    }
    
//    func testNotifyOnSessionProposal() {
//        let topic = "1234"
//        let proposalExpectation = expectation(description: "on session proposal is called after pairing payload")
////        engine.sequencesStore.create(topic: topic, sequenceState: sequencePendingState)
//        try? engine.sequencesStore.setSequence(pendingPairing)
//        let subscriptionPayload = WCRequestSubscriptionPayload(topic: topic, clientSynchJsonRpc: sessionProposal)
//        engine.onSessionProposal = { (_) in
//            proposalExpectation.fulfill()
//        }
//        subscriber.onRequestSubscription?(subscriptionPayload)
//        waitForExpectations(timeout: 0.01, handler: nil)
//    }
}
