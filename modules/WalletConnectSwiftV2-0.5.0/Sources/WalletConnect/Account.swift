/**
 A value that identifies an account in any given blockchain.
 
 This structure parses account IDs according to [CAIP-10].
 Account IDs are prefixed with a [CAIP-2] blockchain ID, delimited by a `':'` character, followed by the account address.
 
 Specifying a blockchain account by using a chain-agnostic identifier is useful to allow interoperability between multiple
 chains when using both wallets and decentralized applications.
 
 [CAIP-2]:https://github.com/ChainAgnostic/CAIPs/blob/master/CAIPs/caip-2.md
 [CAIP-10]:https://github.com/ChainAgnostic/CAIPs/blob/master/CAIPs/caip-10.md
 */
public struct Account: Equatable, Hashable {
    
    /// A blockchain namespace. Usually describes an ecosystem or standard.
    public let namespace: String
    
    /// A reference string that identifies a blockchain within a given namespace.
    public let reference: String
    
    /// The account's address specific to the blockchain.
    public let address: String
    
    /// The CAIP-2 blockchain identifier of the account.
    public var blockchainIdentifier: String {
        "\(namespace):\(reference)"
    }
    
    /// The CAIP-10 account identifier absolute string.
    public var absoluteString: String {
        "\(namespace):\(reference):\(address)"
    }
    
    /// Returns whether the account conforms to CAIP-10.
    public var isCAIP10Conformant: Bool {
        String.conformsToCAIP10(absoluteString)
    }
    
    /**
     Creates an account instance from the provided string.
     
     This initializer returns nil if the string doesn't represent a valid account id in conformance with
     [CAIP-10](https://github.com/ChainAgnostic/CAIPs/blob/master/CAIPs/caip-10.md).
     */
    public init?(_ string: String) {
        guard String.conformsToCAIP10(string) else { return nil }
        let splits = string.split(separator: ":")
        self.init(namespace: String(splits[0]), reference: String(splits[1]), address: String(splits[2]))
    }
    
    /**
     Creates an account instance from a chain ID and an address.
     
     This initializer returns nil if the `chainIdentifier` parameter doesn't represent a valid chain id in conformance with
     [CAIP-2](https://github.com/ChainAgnostic/CAIPs/blob/master/CAIPs/caip-2.md) or if the `address` format is invalid.
     */
    public init?(chainIdentifier: String, address: String) {
        self.init("\(chainIdentifier):\(address)")
    }
    
    /**
     Creates an account instance directly from the base components.
     
     This initializer bypass any checks to CAIP conformance, make sure to pass valid values as parameters.
     */
    public init(namespace: String, reference: String, address: String) {
        self.namespace = namespace
        self.reference = reference
        self.address = address
    }
}

extension Account: LosslessStringConvertible {
    public var description: String {
        return absoluteString
    }
}

extension Account: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let absoluteString = try container.decode(String.self)
        guard let account = Account(absoluteString) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Malformed CAIP-10 account identifier.")
        }
        self = account
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(absoluteString)
    }
}
