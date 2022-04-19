import Foundation

public struct AgreementSecret: Equatable {
    
    public let sharedSecret: Data
    public let publicKey: AgreementPublicKey
    
    public func derivedTopic() -> String {
        sharedSecret.sha256().toHexString()
    }
}

extension AgreementSecret: GenericPasswordConvertible {
    
    public init<D>(rawRepresentation data: D) throws where D : ContiguousBytes {
        let buffer = data.withUnsafeBytes { Data($0) }
        guard buffer.count == 64 else {
            fatalError() // TODO: Handle error
        }
        self.sharedSecret = buffer.subdata(in: 0..<32)
        self.publicKey = try AgreementPublicKey(rawRepresentation: buffer.subdata(in: 32..<64))
    }
    
    public var rawRepresentation: Data {
        sharedSecret + publicKey.rawRepresentation
    }
}
