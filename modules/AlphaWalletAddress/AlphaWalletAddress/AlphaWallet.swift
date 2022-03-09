// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore
import WalletCore

///Use an enum as a namespace until Swift has proper namespaces
public enum AlphaWallet {}

//TODO move this to a standard alone internal Pod with 0 external dependencies so main app and TokenScript can use it?
extension AlphaWallet {
    public enum Address: Hashable, Codable {
        //Computing EIP55 is really slow. Cache needed when we need to create many addresses, like parsing a whole lot of Ethereum event logs
        //there is cases when cache accessing from different treads, fro this case we need to use sync access for it
        private static var cache: ThreadSafeDictionary<String, AlphaWallet.Address> = .init()

        case ethereumAddress(eip55String: String)

        enum Key: CodingKey {
            case ethereumAddress
        }

        public init?(string: String) {
            if let value = Self.cache[string] {
                self = value
                return
            }
            let string = string.add0x
            guard string.count == 42 else { return nil }
            //Workaround for crash on iOS 11 and 12 when built with Xcode 11.3 (for iOS 13). Passing in `string` crashes with specific addresses at specific places, perhaps due to a compiler/runtime bug with following error message despite subscripting being done correctly:
            //    Terminating app due to uncaught exception 'NSRangeException', reason: '*** -[NSPathStore2 characterAtIndex:]: index (42) beyond bounds (42)'
            guard let address = TrustKeystore.Address(string: "\(string)") else { return nil }
            self = .ethereumAddress(eip55String: address.eip55String)
            Self.cache[string] = self
        }

        //TODO not sure if we should keep this
        public init?(uncheckedAgainstNullAddress string: String) {
            if let value = Self.cache[string] {
                self = value
                return
            }

            let string = string.add0x
            guard string.count == 42 else { return nil }
            guard let address = TrustKeystore.Address(uncheckedAgainstNullAddress: string) else { return nil }
            self = .ethereumAddress(eip55String: address.eip55String)
            Self.cache[string] = self
        }

        public init(fromPrivateKey privateKey: Data) {
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

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(eip55String, forKey: .ethereumAddress)
        }

        //TODO reduce usage
        public func sameContract(as contract: String) -> Bool {
            return eip55String.drop0x.lowercased() == contract.drop0x.lowercased()
        }

        public func sameContract(as contract: AlphaWallet.Address) -> Bool {
            return eip55String == contract.eip55String
        }
    }
}

extension AlphaWallet.Address {
    public static func == (lsh: AlphaWallet.Address, rhs: AlphaWallet.Address) -> Bool {
        return lsh.sameContract(as: rhs)
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
