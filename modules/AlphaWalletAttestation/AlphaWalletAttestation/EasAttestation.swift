// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

struct EasAttestation: Codable, Hashable {
    let version: String
    let chainId: Int
    let verifyingContract: String
    let r: [UInt8]
    let s: [UInt8]
    let v: UInt8
    let signer: AlphaWallet.Address
    let uid: String
    let schema: String
    let recipient: String
    let time: Int
    let expirationTime: Int
    let refUID: String
    let revocable: Bool
    let data: String
    let nonce: Int

    //`primaryType` needs to be "Attest" instead of "Attestation" to match the type definition in `types` unlike EAS examples
    var eip712Representation: String {
        return """
               {
                   "types": {
                       "EIP712Domain": [
                           {
                               "name": "name",
                               "type": "string"
                           },
                           {
                               "name": "version",
                               "type": "string"
                           },
                           {
                               "name": "chainId",
                               "type": "uint256"
                           },
                           {
                               "name": "verifyingContract",
                               "type": "address"
                           }
                       ],
                       "Attest": [
                           {
                               "name": "schema",
                               "type": "bytes32"
                           },
                           {
                               "name": "recipient",
                               "type": "address"
                           },
                           {
                               "name": "time",
                               "type": "uint64"
                           },
                           {
                               "name": "expirationTime",
                               "type": "uint64"
                           },
                           {
                               "name": "revocable",
                               "type": "bool"
                           },
                           {
                               "name": "refUID",
                               "type": "bytes32"
                           },
                           {
                               "name": "data",
                               "type": "bytes"
                           }
                       ]
                   },
                   "primaryType": "Attest",
                   "domain": {
                       "name": "EAS Attestation",
                       "version": "\(version)",
                       "chainId": \(chainId),
                       "verifyingContract": "\(verifyingContract)"
                   },
                   "message": {
                       "time": \(time),
                       "data": "\(data)",
                       "expirationTime": \(expirationTime),
                       "recipient": "\(recipient)",
                       "refUID": "\(refUID)",
                       "revocable": \(revocable),
                       "schema": "\(schema)"
                   }
               }
               """
    }

    init(fromAttestationArrayString src: EasAttestationFromArrayString) {
        version = src.version
        chainId = src.chainId
        verifyingContract = src.verifyingContract
        r = src.r
        s = src.s
        v = src.v
        signer = src.signer
        uid = src.uid
        schema = src.schema
        recipient = src.recipient
        time = src.time
        expirationTime = src.expirationTime
        refUID = src.refUID
        revocable = src.revocable
        data = src.data
        nonce = src.nonce
    }
}

struct EasAttestationFromArrayString: Decodable {
    private struct ParsingError: Error {
        let fieldName: String
    }

    let version: String
    let chainId: Int
    let verifyingContract: String
    let r: [UInt8]
    let s: [UInt8]
    let v: UInt8
    let signer: AlphaWallet.Address
    let uid: String
    let schema: String
    let recipient: String
    let time: Int
    let expirationTime: Int
    let refUID: String
    let revocable: Bool
    let data: String
    let nonce: Int

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        version = try container.decode(String.self)
        chainId = try container.decode(Int.self)
        verifyingContract = try container.decode(String.self)
        let _r = try container.decode(String.self)
        r = functional.stringToInt8Array(_r)
        let _s = try container.decode(String.self)
        s = functional.stringToInt8Array(_s)
        v = try container.decode(UInt8.self)
        signer = try AlphaWallet.Address(uncheckedAgainstNullAddress: try container.decode(String.self)) ?? {
            throw ParsingError(fieldName: "signer")
        }()
        uid = try container.decode(String.self)
        schema = try container.decode(String.self)
        let _recipient = try container.decode(String.self)
        if _recipient == "0" {
            recipient = "0x0000000000000000000000000000000000000000"
        } else {
            recipient = _recipient
        }
        time = try container.decode(Int.self)
        expirationTime = try container.decode(Int.self)
        let _refUID = try container.decode(String.self)
        if _refUID == "0" {
            refUID = "0x0000000000000000000000000000000000000000000000000000000000000000"
        } else {
            refUID = _refUID
        }
        revocable = try container.decode(Bool.self)
        data = try container.decode(String.self)
        nonce = try container.decode(Int.self)
    }

    enum functional {}
}

fileprivate extension EasAttestationFromArrayString.functional {
    static func stringToInt8Array(_ hexString: String) -> [UInt8] {
        let hexString = hexString.drop0x
        let data = Data(hex: hexString)
        let result: [UInt8] = data.map { UInt8($0) }
        return result
    }
}
