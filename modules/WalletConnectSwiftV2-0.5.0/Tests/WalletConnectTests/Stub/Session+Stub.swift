import Foundation
import WalletConnectKMS
@testable import WalletConnect

extension SessionSequence {
    
    static func stubPreSettled(isPeerController: Bool = false) -> SessionSequence {
        let peerKey = AgreementPrivateKey().publicKey.hexRepresentation
        let permissions = isPeerController ? SessionPermissions.stub(controllerKey: peerKey) : SessionPermissions.stub()
        return SessionSequence(
            topic: String.generateTopic()!,
            relay: RelayProtocolOptions.stub(),
            selfParticipant: Participant.stub(),
            expiryDate: Date.distantFuture,
            settledState: Settled(
                peer: Participant.stub(publicKey: peerKey),
                permissions: permissions,
                state: SessionState(accounts: ["chainstd:1:1"]),
                status: .preSettled
            )
        )
    }
    
    static func stubSettled(isSelfController: Bool) -> SessionSequence {
        let peerKey = AgreementPrivateKey().publicKey.hexRepresentation
        let selfKey = AgreementPrivateKey().publicKey.hexRepresentation
        let permissions = isSelfController ? SessionPermissions.stub(controllerKey: selfKey) : SessionPermissions.stub(controllerKey: peerKey)
        return SessionSequence(
            topic: String.generateTopic()!,
            relay: RelayProtocolOptions.stub(),
            selfParticipant: Participant.stub(publicKey: selfKey),
            expiryDate: Date.distantFuture,
            settledState: Settled(
                peer: Participant.stub(publicKey: peerKey),
                permissions: permissions,
                state: SessionState(accounts: ["chainstd:1:1"]),
                status: .acknowledged
            )
        )
    }
}
