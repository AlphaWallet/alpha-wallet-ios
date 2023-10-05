// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore

///Use an enum as a namespace until Swift has proper namespaces
public enum AlphaWallet {}

//TODO move this to a standard alone internal Pod with 0 external dependencies so main app and TokenScript can use it?
extension AlphaWallet {
    public enum Address: Hashable, Codable {
        //Computing EIP55 is really slow. Cache needed when we need to create many addresses, like parsing a whole lot of Ethereum event logs there is cases when cache accessing from different treads, for this case we need to use sync access for it
        public static var sharedAddressStorage: AddressStorage?

        case ethereumAddress(eip55String: String)

        enum Key: CodingKey {
            case ethereumAddress
        }

        public init?(string: String) {
            if let address = Self.sharedAddressStorage?[string.lowercased()] {
                self = address
                return
            }
            let string = string.add0x
            guard string.count == 42 else { return nil }
            //Workaround for crash on iOS 11 and 12 when built with Xcode 11.3 (for iOS 13). Passing in `string` crashes with specific addresses at specific places, perhaps due to a compiler/runtime bug with following error message despite subscripting being done correctly:
            //    Terminating app due to uncaught exception 'NSRangeException', reason: '*** -[NSPathStore2 characterAtIndex:]: index (42) beyond bounds (42)'
            guard let address = TrustKeystore.Address(string: "\(string)") else { return nil }
            self = .ethereumAddress(eip55String: address.eip55String)
            Self.sharedAddressStorage?[string.lowercased()] = self
        }

        //TODO not sure if we should keep this
        public init?(uncheckedAgainstNullAddress string: String) {
            if let address = Self.sharedAddressStorage?[string.lowercased()] {
                self = address
                return
            }

            let string = string.add0x
            guard string.count == 42 else { return nil }
            guard let address = TrustKeystore.Address(uncheckedAgainstNullAddress: string) else { return nil }
            self = .ethereumAddress(eip55String: address.eip55String)
            Self.sharedAddressStorage?[string.lowercased()] = self
        }

        public init?(fromPrivateKey privateKey: Data) {
            guard functional.validatePrivateKey(privateKey) else { return nil }
            let publicKey = Secp256k1.shared.pubicKey(from: privateKey)
            self = Address.deriveEthereumAddress(fromPublicKey: publicKey)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            let address = try container.decode(String.self, forKey: .ethereumAddress)
            self = .ethereumAddress(eip55String: address)
        }

        //TODO look for references to this and remove as many as possible. Use the Address type as much as possible. Only convert to string or another address type when strictly necessary
        public var eip55String: String {
            switch self {
            case .ethereumAddress(let string):
                return string
            }
        }

        public var data: Data {
            //Forced unwrap because we trust that the string is EIP55
            return Data(hexString: eip55String)!
        }

        public var isNull: Bool {
            eip55String == "0x0000000000000000000000000000000000000000"
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(eip55String, forKey: .ethereumAddress)
        }

        //TODO reduce usage
        public func sameContract(as contract: String) -> Bool {
            return eip55String.drop0x.lowercased() == contract.drop0x.lowercased()
        }
    }
}

extension AlphaWallet.Address {
    enum functional {}
}

fileprivate extension AlphaWallet.Address.functional {
    //TODO Should exploring using secp256k1_ec_seckey_verify() instead
    static func validatePrivateKey(_ privateKey: Data) -> Bool {
        //See https://en.bitcoin.it/wiki/Secp256k1 for n, order of curve
        let n = "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141"
        let privateKey = privateKey.hex().lowercased()
        let allZeros = "0000000000000000000000000000000000000000000000000000000000000000"
        if privateKey.count != 64 {
            return false
        }
        if privateKey == allZeros {
            return false
        }
        if privateKey >= n {
            return false
        }
        return true
    }
}

extension AlphaWallet.Address: CustomStringConvertible {
    //TODO should not be using this in production code
    public var description: String {
        return eip55String
    }
}

extension AlphaWallet.Address: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .ethereumAddress(let eip55String):
            return "ethereumAddress: \(eip55String)"
        }
    }
}

extension AlphaWallet.Address {
    private static func deriveEthereumAddress(fromPublicKey publicKey: Data) -> AlphaWallet.Address {
        precondition(publicKey.count == 65, "Expect 64-byte public key")
        precondition(publicKey[0] == 4, "Invalid public key")
        let sha3 = publicKey[1...].sha3(.keccak256)
        let eip55String = sha3[12..<32].hex()
        return AlphaWallet.Address(string: eip55String)!
    }
}

extension AlphaWallet.Address {
    //Produces this format: 0x1234…5678
    public var truncateMiddle: String {
        let address = eip55String
        let front = address.prefix(6)
        let back = address.suffix(4)
        return "\(front)…\(back)"
    }
}

fileprivate extension String {
    var add0x: String {
        if hasPrefix("0x") {
            return self
        } else {
            return "0x" + self
        }
    }

    var drop0x: String {
        if count > 2 && substring(with: 0..<2) == "0x" {
            return String(dropFirst(2))
        }
        return self
    }

    func index(from: Int) -> Index {
        return index(startIndex, offsetBy: from)
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
}

fileprivate extension Data {
    struct HexEncodingOptions: OptionSet {
        public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    func hex(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}