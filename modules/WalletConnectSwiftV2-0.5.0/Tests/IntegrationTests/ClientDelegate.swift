
import Foundation
@testable import WalletConnect

class ClientDelegate: WalletConnectClientDelegate {
    var client: WalletConnectClient
    var onSessionSettled: ((Session)->())?
    var onPairingSettled: ((Pairing)->())?
    var onSessionProposal: ((Session.Proposal)->())?
    var onSessionRequest: ((Request)->())?
    var onSessionResponse: ((Response)->())?
    var onSessionRejected: ((String, Reason)->())?
    var onSessionDelete: (()->())?
    var onSessionUpgrade: ((String, Session.Permissions)->())?
    var onSessionUpdate: ((String, Set<Account>)->())?
    var onNotificationReceived: ((Session.Notification, String)->())?
    var onPairingUpdate: ((String, AppMetadata)->())?
    
    internal init(client: WalletConnectClient) {
        self.client = client
        client.delegate = self
    }
    
    func didReject(pendingSessionTopic: String, reason: Reason) {
        onSessionRejected?(pendingSessionTopic, reason)
    }
    func didSettle(session: Session) {
        onSessionSettled?(session)
    }
    func didSettle(pairing: Pairing) {
        onPairingSettled?(pairing)
    }
    func didReceive(sessionProposal: Session.Proposal) {
        onSessionProposal?(sessionProposal)
    }
    func didReceive(sessionRequest: Request) {
        onSessionRequest?(sessionRequest)
    }
    func didDelete(sessionTopic: String, reason: Reason) {
        onSessionDelete?()
    }
    func didUpgrade(sessionTopic: String, permissions: Session.Permissions) {
        onSessionUpgrade?(sessionTopic, permissions)
    }
    func didUpdate(sessionTopic: String, accounts: Set<Account>) {
        onSessionUpdate?(sessionTopic, accounts)
    }
    func didReceive(notification: Session.Notification, sessionTopic: String) {
        onNotificationReceived?(notification, sessionTopic)
    }
    func didUpdate(pairingTopic: String, appMetadata: AppMetadata) {
        onPairingUpdate?(pairingTopic, appMetadata)
    }
    func didReceive(sessionResponse: Response) {
        onSessionResponse?(sessionResponse)
    }
}
