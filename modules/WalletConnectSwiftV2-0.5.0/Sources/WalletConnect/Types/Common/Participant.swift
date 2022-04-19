struct Participant: Codable, Equatable {
    let publicKey: String
    let metadata: AppMetadata?
    
    init(publicKey: String, metadata: AppMetadata? = nil) {
        self.publicKey = publicKey
        self.metadata = metadata
    }
}

struct PairingParticipant: Codable, Equatable {
    let publicKey: String
}

struct SessionParticipant: Codable, Equatable {
    let publicKey: String
    let metadata: AppMetadata
}
