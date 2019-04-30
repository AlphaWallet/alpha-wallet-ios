// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
//TODO remove all dependencies
import TrustKeystore

///Use an enum as a namespace until Swift has proper namespaces
enum AlphaWallet {}

//TODO move this to a standard alone internal Pod with 0 external dependencies so main app and TokenScript can use it?
extension AlphaWallet {
    enum Address: Hashable, Codable {
        case ethereumAddress(eip55String: String)

        enum Key: CodingKey {
            case ethereumAddress
        }

        init?(string: String) {
            guard let address = TrustKeystore.Address(string: string) else { return nil }
            self = .ethereumAddress(eip55String: address.eip55String)
        }

        //TODO not sure if we should keep this
        init?(uncheckedAgainstNullAddress string: String) {
            guard let address = TrustKeystore.Address(uncheckedAgainstNullAddress: string) else { return nil }
            self = .ethereumAddress(eip55String: address.eip55String)
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            let address = try container.decode(String.self, forKey: .ethereumAddress)
            self = .ethereumAddress(eip55String: address)
        }

        //TODO look for references to this and remove as many as possible. Use the Address type as much as possible. Only convert to string or another address type when strictly necessary
        var eip55String: String {
            switch self {
            case .ethereumAddress(let string):
                return string
            }
        }

        var data: Data {
            //Forced unwrap because we trust that the string is EIP55
            return Data(hexString: eip55String)!
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(eip55String, forKey: .ethereumAddress)
        }

        //TODO reduce usage
        func sameContract(as contract: String) -> Bool {
            return eip55String.drop0x.lowercased() == contract.drop0x.lowercased()
        }
    }
}

extension AlphaWallet.Address: CustomStringConvertible {
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
