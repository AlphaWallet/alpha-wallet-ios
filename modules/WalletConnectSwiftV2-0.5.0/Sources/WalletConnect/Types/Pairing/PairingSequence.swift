import Foundation
import WalletConnectKMS

struct PairingSequence: ExpirableSequence {
    let topic: String
    let relay: RelayProtocolOptions
    let selfParticipant: Participant
    let expiryDate: Date
    private var sequenceState: Either<Pending, Settled>
    
    var publicKey: String {
        selfParticipant.publicKey
    }
    
    func getPublicKey() throws -> AgreementPublicKey {
        try AgreementPublicKey(rawRepresentation: Data(hex: selfParticipant.publicKey))
    }

    var pending: Pending? {
        get {
            sequenceState.left
        }
        set {
            if let pending = newValue {
                sequenceState = .left(pending)
            }
        }
    }
    
    var settled: Settled? {
        get {
            sequenceState.right
        }
        set {
            if let settled = newValue {
                sequenceState = .right(settled)
            }
        }
    }
    
    var isSettled: Bool {
        settled != nil
    }
    
    var peerIsController: Bool {
        isSettled && settled?.peer.publicKey == settled?.permissions.controller.publicKey
    }
    
    static var timeToLiveProposed: Int {
        Time.hour
    }
    
    static var timeToLivePending: Int {
        Time.day
    }
    
    static var timeToLiveSettled: Int {
        Time.day * 30
    }
}

extension PairingSequence {
    
    struct Pending: Codable {
        let proposal: PairingProposal
        let status: Status
        
        var isResponded: Bool {
            guard case .responded = status else { return false }
            return true
        }
        
        enum Status: Codable {
            case proposed
            case responded(String)
        }
    }

    struct Settled: Codable {
        let peer: Participant
        let permissions: PairingType.Permissions
        var state: PairingState?
        var status: Status
        
        enum Status: Codable {
            case preSettled
            case acknowledged
        }
    }
}

// MARK: - Initialization

extension PairingSequence {
    
    init(topic: String, relay: RelayProtocolOptions, selfParticipant: Participant, expiryDate: Date, pendingState: Pending) {
        self.init(topic: topic, relay: relay, selfParticipant: selfParticipant, expiryDate: expiryDate, sequenceState: .left(pendingState))
    }
    
    init(topic: String, relay: RelayProtocolOptions, selfParticipant: Participant, expiryDate: Date, settledState: Settled) {
        self.init(topic: topic, relay: relay, selfParticipant: selfParticipant, expiryDate: expiryDate, sequenceState: .right(settledState))
    }
    
    static func buildProposed(uri: WalletConnectURI) -> PairingSequence {
        let proposal = PairingProposal.createFromURI(uri)
        return PairingSequence(
            topic: proposal.topic,
            relay: proposal.relay,
            selfParticipant: Participant(publicKey: proposal.proposer.publicKey),
            expiryDate: Date(timeIntervalSinceNow: TimeInterval(timeToLiveProposed)),
            pendingState: Pending(proposal: proposal, status: .proposed)
        )
    }
    
    static func buildResponded(proposal: PairingProposal, agreementKeys: AgreementSecret) -> PairingSequence {
        PairingSequence(
            topic: proposal.topic,
            relay: proposal.relay,
            selfParticipant: Participant(publicKey: agreementKeys.publicKey.hexRepresentation),
            expiryDate: Date(timeIntervalSinceNow: TimeInterval(Time.day)),
            pendingState: Pending(
                proposal: proposal,
                status: .responded(agreementKeys.derivedTopic())
            )
        )
    }
    
    static func buildPreSettled(proposal: PairingProposal, agreementKeys: AgreementSecret) -> PairingSequence {
        let controllerKey = proposal.proposer.controller ? proposal.proposer.publicKey : agreementKeys.publicKey.hexRepresentation
        return PairingSequence(
            topic: agreementKeys.derivedTopic(),
            relay: proposal.relay,
            selfParticipant: Participant(publicKey: agreementKeys.publicKey.hexRepresentation),
            expiryDate: Date(timeIntervalSinceNow: TimeInterval(proposal.ttl)),
            settledState: Settled(
                peer: Participant(publicKey: proposal.proposer.publicKey),
                permissions: PairingType.Permissions(
                    jsonrpc: proposal.permissions.jsonrpc,
                    controller: Controller(publicKey: controllerKey)),
                state: nil,
                status: .preSettled
            )
        )
    }
    
    static func buildAcknowledged(approval approveParams: PairingType.ApprovalParams, proposal: PairingProposal, agreementKeys: AgreementSecret) -> PairingSequence {
        let controllerKey = proposal.proposer.controller ? proposal.proposer.publicKey : approveParams.responder.publicKey
        return PairingSequence(
            topic: agreementKeys.derivedTopic(),
            relay: approveParams.relay , // Is it safe to just accept the approval params blindly?
            selfParticipant: Participant(publicKey: agreementKeys.publicKey.hexRepresentation),
            expiryDate: Date(timeIntervalSince1970: TimeInterval(approveParams.expiry)),
            settledState: Settled(
                peer: Participant(publicKey: approveParams.responder.publicKey),
                permissions: PairingType.Permissions(
                    jsonrpc: proposal.permissions.jsonrpc,
                    controller: Controller(publicKey: controllerKey)),
                state: approveParams.state,
                status: .acknowledged
            )
        )
    }
}
