@testable import WalletConnect
import WalletConnectKMS

extension AppMetadata {
    static func stub() -> AppMetadata {
        AppMetadata(
            name: "Wallet Connect",
            description: "A protocol to connect blockchain wallets to dapps.",
            url: "https://walletconnect.com/",
            icons: []
        )
    }
}

extension Pairing {
    static func stub() -> Pairing {
        Pairing(topic: String.generateTopic()!, peer: nil)
    }
}

extension Session.Permissions {
    static func stub(
        chains: Set<String> = ["solana:4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZ"],
        methods: Set<String> = ["getGenesisHash"],
        notifications: [String] = ["msg"]
    ) -> Session.Permissions {
        Session.Permissions(
            blockchains: chains,
            methods: methods,
            notifications: notifications
        )
    }
}

extension SessionPermissions {
    static func stub(
        chains: Set<String> = ["eip155:1"],
        jsonrpc: Set<String> = ["eth_sign"],
        notifications: [String] = ["a_type"],
        controllerKey: String = AgreementPrivateKey().publicKey.hexRepresentation
    ) -> SessionPermissions {
        return SessionPermissions(
            blockchain: Blockchain(chains: chains),
            jsonrpc: JSONRPC(methods: jsonrpc),
            notifications: Notifications(types: notifications),
            controller: Controller(publicKey: controllerKey)
        )
    }
}

extension RelayProtocolOptions {
    static func stub() -> RelayProtocolOptions {
        RelayProtocolOptions(protocol: "", params: nil)
    }
}

extension Participant {
    static func stub(publicKey: String = AgreementPrivateKey().publicKey.hexRepresentation) -> Participant {
        Participant(publicKey: publicKey, metadata: AppMetadata.stub())
    }
}

extension WCRequestSubscriptionPayload {
    static func stubUpdate(topic: String, accounts: Set<String> = ["std:0:0"]) -> WCRequestSubscriptionPayload {
        let updateMethod = WCMethod.wcSessionUpdate(SessionType.UpdateParams(accounts: accounts)).asRequest()
        return WCRequestSubscriptionPayload(topic: topic, wcRequest: updateMethod)
    }
    
    static func stubUpgrade(topic: String, permissions: SessionPermissions = SessionPermissions(permissions: Session.Permissions.stub())) -> WCRequestSubscriptionPayload {
        let upgradeMethod = WCMethod.wcSessionUpgrade(SessionType.UpgradeParams(permissions: permissions)).asRequest()
        return WCRequestSubscriptionPayload(topic: topic, wcRequest: upgradeMethod)
    }
}
