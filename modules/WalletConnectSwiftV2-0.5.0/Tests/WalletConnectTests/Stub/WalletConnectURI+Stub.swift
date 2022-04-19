@testable import WalletConnect
@testable import WalletConnectKMS

extension WalletConnectURI {
    
    static func stub(isController: Bool = false) -> WalletConnectURI {
        WalletConnectURI(
            topic: String.generateTopic()!,
            publicKey: AgreementPrivateKey().publicKey.hexRepresentation,
            isController: isController,
            relay: RelayProtocolOptions(protocol: "", params: nil)
        )
    }
}
