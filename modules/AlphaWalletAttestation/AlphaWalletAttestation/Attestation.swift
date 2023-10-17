// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import Gzip
import AlphaWalletABI
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletWeb3
import BigInt

public enum AttestationPropertyValue: Codable, Hashable {
    case address(AlphaWallet.Address)
    case string(String)
    case bytes(Data)
    case int(BigInt)
    case uint(BigUInt)
    case bool(Bool)

    enum Key: CodingKey {
        case address
        case string
        case bytes
        case int
        case uint
        case bool
    }

    enum CodingError: Error {
        case cannotDecode
    }

    public var stringValue: String {
        switch self {
        case .address(let address):
            return address.eip55String
        case .string(let string):
            return string
        case .bytes(let data):
            return data.hexEncoded
        case .int(let int):
            return String(describing: int)
        case .uint(let uint):
            return String(describing: uint)
        case .bool(let bool):
            return String(describing: bool)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)

        if let address = try? container.decode(AlphaWallet.Address.self, forKey: .address) {
            self = .address(address)
            return
        }
        if let string = try? container.decode(String.self, forKey: .string) {
            self = .string(string)
            return
        }
        if let bytes = try? container.decode(Data.self, forKey: .bytes) {
            self = .bytes(bytes)
            return
        }
        if let int = try? container.decode(BigInt.self, forKey: .int) {
            self = .int(int)
            return
        }
        if let uint = try? container.decode(BigUInt.self, forKey: .uint) {
            self = .uint(uint)
            return
        }
        if let bool = try? container.decode(Bool.self, forKey: .bool) {
            self = .bool(bool)
            return
        }
        throw CodingError.cannotDecode
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .address(let value):
            try container.encode(value, forKey: .address)
        case .string(let value):
            try container.encode(value, forKey: .string)
        case .int(let value):
            try container.encode(value, forKey: .int)
        case .uint(let value):
            try container.encode(value, forKey: .uint)
        case .bool(let value):
            try container.encode(value, forKey: .bool)
        case .bytes(let value):
            try container.encode(value, forKey: .bytes)
        }
    }
}

public struct Attestation: Codable, Hashable {
    public struct SchemaUid: Hashable, Codable, ExpressibleByStringLiteral {
        public let value: String

        public init(stringLiteral value: StringLiteralType) {
            self.value = value
        }

        public init(value: String) {
            self.value = value
        }
    }

    public struct Schema: ExpressibleByStringLiteral {
        public let value: String

        public init(stringLiteral value: StringLiteralType) {
            self.value = value
        }

        public init(value: String) {
            self.value = value
        }
    }

    public struct AttestationId: Hashable {
        public let value: String
    }

    //Redefine here so reduce dependencies
    static var vitaliklizeConstant: UInt8 = 27

    public static var callSmartContract: ((RPCServer, AlphaWallet.Address, String, String, [AnyObject]) async throws -> [String: Any])!
    public static var isLoggingEnabled = false

    public struct TypeValuePair: Codable, Hashable {
        public let type: ABIv2.Element.InOut
        public let value: AttestationPropertyValue

        public init(type: ABIv2.Element.InOut, value: AttestationPropertyValue) {
            self.type = type
            self.value = value
        }

        static func mapValue(of output: ABIv2.Element.ParameterType, for value: AnyObject) -> AttestationPropertyValue {
            switch output {
            case .address:
                if let value = value as? AlphaWalletWeb3.EthereumAddress {
                    let result = AlphaWallet.Address(address: value)
                    return .address(result)
                }
                return .bool(false)
            case .bool:
                let result = value as? Bool ?? false
                return .bool(result)
            case .bytes:
                let result = value as? Data ?? Data()
                return .bytes(result)
            case .string:
                let result = value as? String ?? ""
                return .string(result)
            case .uint:
                let result = value as? BigUInt ?? BigUInt(0)
                return .uint(result)
            case .int:
                let result = value as? BigInt ?? BigInt(0)
                return .int(result)
            case .function:
                return .bool(false)
            case .array:
                //TODO support?
                return .bool(false)
            case .dynamicBytes:
                return .bytes(value as? Data ?? Data())
            case .tuple:
                //TODO support?
                return .bool(false)
            }
        }
    }

    enum AttestationError: Error {
        case extractAttestationFailed(AttestationInternalError)
        case ecRecoverFailed(AttestationInternalError)
        case validateSignatureFailed(server: RPCServer, signerAddress: AlphaWallet.Address, error: AttestationInternalError)
        case schemaRecordNotFound(RPCServer, AttestationInternalError)
        case chainNotSupported(server: RPCServer, error: AttestationInternalError)
        case ecRecoveredSignerDoesNotMatch
        case parseAttestationUrlFailed(String)
    }

    enum AttestationInternalError: Error {
        case unzipAttestationFailed(zipped: String)
        case decodeAttestationArrayStringFailed(zipped: String)
        case decodeEasAttestationFailed(zipped: String)
        case extractAttestationDataFailed(attestation: EasAttestation)
        case validateSignatureFailed(server: RPCServer, signerAddress: AlphaWallet.Address)
        case generateEip712Failed(attestation: EasAttestation)
        case reconstructSignatureFailed(attestation: EasAttestation, v: UInt8, r: [UInt8], s: [UInt8])
        case schemaRecordNotFound(keySchemaUid: Attestation.SchemaUid, server: RPCServer)
        case keySchemaUidNotFound(server: RPCServer)
        case easSchemaContractNotFound(server: RPCServer)
        case rootKeyUidNotFound(server: RPCServer)
        case easContractNotFound(server: RPCServer)
    }

    public let data: [TypeValuePair]
    public let source: String
    private let easAttestation: EasAttestation
    public let isValidAttestationIssuer: Bool

    public var easAttestationData: String { easAttestation.data }
    public var easAttestationTime: Int { easAttestation.time }
    public var easAttestationExpirationTime: Int { easAttestation.expirationTime }
    public var attestationId: AttestationId {
        AttestationId(value: easAttestation.uid)
    }
    public var recipient: AlphaWallet.Address? {
        return AlphaWallet.Address(uncheckedAgainstNullAddress: easAttestation.recipient)
    }
    public var time: Date { Date(timeIntervalSince1970: TimeInterval(easAttestation.time)) }
    public var expirationTime: Date? {
        if easAttestation.expirationTime < easAttestation.time {
            return nil
        } else {
            return Date(timeIntervalSince1970: TimeInterval(easAttestation.expirationTime))
        }
    }

    public var verifyingContract: AlphaWallet.Address? { AlphaWallet.Address(string: easAttestation.verifyingContract) }
    public var signer: AlphaWallet.Address { easAttestation.signer }
    public var server: RPCServer { easAttestation.server }
    //Good for debugging, in case converting to `RPCServer` is done wrongly
    public var chainId: Int { easAttestation.chainId }
    public var version: String { easAttestation.version }
    public var refUID: String { easAttestation.refUID }
    public var revocable: Bool { easAttestation.revocable }
    //EAS's schema here *does* refer to the schema UID
    public var schemaUid: SchemaUid { SchemaUid(value: easAttestation.schema) }
    public var easMessageVersion: Int? { easAttestation.messageVersion }
    public var scriptUri: URL? {
        let url: URL? = data.compactMap { each in
            if each.type.name == "scriptURI" {
                switch each.value {
                case .string(let value):
                    return URL(string: value)
                case .address, .bool, .bytes, .int, .uint:
                    return nil
                }
            } else {
                return nil
            }
        }.first
        return url
    }
    public var signature: Data {
        //This expects `v` to be 0x1b/0x1c, so do not implement -27
        if let result: Data = Web3.Utils.marshalSignature(v: easAttestation.v, r: easAttestation.r, s: easAttestation.s) {
            return result
        } else {
            return Data()
        }
    }

    private init(data: [TypeValuePair], easAttestation: EasAttestation, isValidAttestationIssuer: Bool, source: String) {
        self.data = data
        self.easAttestation = easAttestation
        self.isValidAttestationIssuer = isValidAttestationIssuer
        self.source = source
    }

    public func stringProperty(withName name: String) -> String? {
        return data.compactMap { each in
            if each.type.name == name {
                switch each.value {
                case .string(let value):
                    return value
                case .int(let value):
                    return String(value)
                case .uint(let value):
                    return String(value)
                case .address(let value):
                    return value.eip55String
                case .bool, .bytes:
                    return nil
                }
            } else {
                return nil
            }
        }.first
    }

    public static func extract(fromUrlString urlString: String) async throws -> Attestation {
        if let rawAttestation = extractRawAttestation(fromUrlString: urlString) {
            return try await Attestation.extract(fromEncodedValue: rawAttestation, source: urlString)
        } else {
            throw AttestationError.parseAttestationUrlFailed(urlString)
        }
    }

    public static func extractRawAttestation(fromUrlString urlString: String) -> String? {
        if let url = URL(string: urlString),
           let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
           let components = Optional(fragment.split(separator: "=", maxSplits: 1)),
           components.first == "attestation" {
            let encodedAttestation = components[1]
            return String(encodedAttestation)
        } else if let url = URL(string: urlString),
                  let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = urlComponents.queryItems,
                  let ticketItem = queryItems.first(where: { $0.name == "ticket" }) ?? queryItems.first(where: { $0.name == "attestation" }), let encodedAttestation = ticketItem.value {
            return encodedAttestation
        } else {
            return nil
        }
    }

    public static func extract(fromEncodedValue value: String, source: String) async throws -> Attestation {
        do {
            return try await _extractFromEncoded(value, source: source)
        } catch let error as AttestationInternalError {
            infoLog("[Attestation] Caught internal error: \(error)")
            //Wraps with public errors
            switch error {
            case .unzipAttestationFailed, .decodeAttestationArrayStringFailed, .decodeEasAttestationFailed, .extractAttestationDataFailed:
                throw AttestationError.extractAttestationFailed(error)
            case .validateSignatureFailed(let server, let signerAddress):
                throw AttestationError.validateSignatureFailed(server: server, signerAddress: signerAddress, error: error)
            case .generateEip712Failed, .reconstructSignatureFailed:
                throw AttestationError.ecRecoverFailed(error)
            case .schemaRecordNotFound(_, let server):
                throw AttestationError.schemaRecordNotFound(server, error)
            case .keySchemaUidNotFound(let server), .easSchemaContractNotFound(let server), .rootKeyUidNotFound(let server), .easContractNotFound(let server):
                throw AttestationError.chainNotSupported(server: server, error: error)
            }
        } catch {
            throw error
        }
    }

    //Throws internal errors
    private static func _extractFromEncoded(_ scannedValue: String, source: String) async throws -> Attestation {
        let encodedAttestationData = try functional.unzipAttestation(scannedValue)

        guard let attestationArrayString = String(data: encodedAttestationData, encoding: .utf8) else {
            throw AttestationInternalError.decodeAttestationArrayStringFailed(zipped: scannedValue)
        }
        infoLog("[Attestation] Decompressed attestation: \(attestationArrayString)")

        guard let attestationArrayData = attestationArrayString.data(using: .utf8), let attestationFromArrayString = try? JSONDecoder().decode(EasAttestationFromArrayString.self, from: attestationArrayData) else {
            throw AttestationInternalError.decodeEasAttestationFailed(zipped: scannedValue)
        }
        let attestation = EasAttestation(fromAttestationArrayString: attestationFromArrayString)

        let isEcRecoveredSignerMatches = try functional.checkEcRecoveredSignerMatches(attestation: attestation)
        infoLog("[Attestation] ec-recovered signer matches: \(isEcRecoveredSignerMatches)")
        guard isEcRecoveredSignerMatches else {
            throw AttestationError.ecRecoveredSignerDoesNotMatch
        }

        let isValidAttestationIssuer: Bool
        do {
            isValidAttestationIssuer = try await functional.checkIsValidAttestationIssuer(attestation: attestation)
            infoLog("[Attestation] is signer verified: \(isValidAttestationIssuer)")
        } catch {
            //Important to catch this and not fail attestation parsing, otherwise and RPC node error can break attestations
            infoLog("[Attestation] is signer verified failed with error: \(error)")
            isValidAttestationIssuer = false
        }

        let results: [TypeValuePair] = try await functional.extractAttestationData(attestation: attestation)
        infoLog("[Attestation] decoded attestation data: \(results) isValidAttestationIssuer: \(isValidAttestationIssuer)")

        return Attestation(data: results, easAttestation: attestation, isValidAttestationIssuer: isValidAttestationIssuer, source: source)
    }

    public static func computeAttestationCollectionId(forAttestation attestation: Attestation, collectionIdFields: [AttestationAttribute]) -> String {
        var results: [String] = [
            convertSignerAddressToFormatForComputingCollectionId(signer: attestation.signer)
        ]
        let collectionIdFieldsData = Attestation.resolveAttestationAttributes(forAttestation: attestation, withAttestationFields: collectionIdFields)
        for each in collectionIdFieldsData {
            results.append(each.value.stringValue)
        }
        let collectionId = results.joined()
        let hash = collectionId.sha3(.keccak256)
        return hash
    }

    public static func convertSignerAddressToFormatForComputingCollectionId(signer: AlphaWallet.Address?) -> String {
        //We drop both the 0x, and the leading 04
        signer?.eip55String.lowercased().drop0x.dropLeading04 ?? ""
    }

    enum functional {}
}

fileprivate var attestationDateFormatter = Date.formatter(with: "dd MMM yyyy h:mm:ss a")
extension Attestation {
    public static func resolveAttestationAttributes(forAttestation attestation: Attestation, withAttestationFields attestationFields: [AttestationAttribute]) -> [Attestation.TypeValuePair] {
        return attestationFields.compactMap { eachField -> Attestation.TypeValuePair? in
            let label = eachField.label
            let path = eachField.path
            if path.hasPrefix("data.") {
                let dataFieldName = path.dropDataPrefix
                let match = attestation.data.first { each in
                    return each.type.name == dataFieldName
                }
                return match.flatMap { Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: $0.type.type), value: $0.value) }
            } else {
                switch path {
                case "name":
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string("EAS Attestation"))
                case "version":
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string(attestation.version))
                case "chainId":
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .uint(bits: 256)), value: AttestationPropertyValue.uint(BigUInt(attestation.chainId)))
                case "signer":
                    //We need signer for computation of collectionId or attestation ID (for re-issue, replacements)
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string(attestation.signer.eip55String))
                case "verifyingContract":
                    //TODO be much better if we can specify optionals for types such as Address so when we display in the UI, we can format them better (eg. "0x0000000…") is useless when displayed, it'd be better if we middle truncate them
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string(attestation.verifyingContract?.eip55String ?? ""))
                case "recipient":
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string(attestation.recipient?.eip55String ?? ""))
                case "refUID":
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string(attestation.refUID))
                case "revocable":
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .bool), value: AttestationPropertyValue.bool(attestation.revocable))
                case "schema":
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string(attestation.schemaUid.value))
                case "time":
                    //TODO not good to convert to string here, but type constraints
                    let string = attestationDateFormatter.string(from: attestation.time)
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string(string))
                case "expirationTime":
                    //TODO not good to convert to string here, but type constraints
                    let string = attestation.expirationTime.map { attestationDateFormatter.string(from: $0) } ?? "—"
                    return Attestation.TypeValuePair(type: ABIv2.Element.InOut(name: label, type: .string), value: AttestationPropertyValue.string(string))
                default:
                    return nil
                }
            }
        }
    }
}

//For testing
extension Attestation {
    internal static func extractTypesFromSchemaForTesting(_ schema: Attestation.Schema) -> [ABIv2.Element.InOut]? {
        return functional.extractTypesFromSchema(schema)
    }
}

fileprivate extension Attestation.functional {
    struct SchemaRecord {
        let uid: Attestation.SchemaUid
        let resolver: AlphaWallet.Address
        let revocable: Bool
        let schema: Attestation.Schema
    }

    static func getKeySchemaUid(server: RPCServer) throws -> Attestation.SchemaUid {
        switch server {
        case .main, .arbitrum:
            return "0x5f0437f7c1db1f8e575732ca52cc8ad899b3c9fe38b78b67ff4ba7c37a8bf3b4"
        case .sepolia:
            return "0x4455598d3ec459c4af59335f7729fea0f50ced46cb1cd67914f5349d44142ec1"
        default:
            throw Attestation.AttestationInternalError.keySchemaUidNotFound(server: server)
        }
    }

    static func getEasSchemaContract(server: RPCServer) throws -> AlphaWallet.Address {
        switch server {
        case .main:
            return AlphaWallet.Address(string: "0xA7b39296258348C78294F95B872b282326A97BDF")!
        case .arbitrum:
            return AlphaWallet.Address(string: "0xA310da9c5B885E7fb3fbA9D66E9Ba6Df512b78eB")!
        case .sepolia:
            return AlphaWallet.Address(string: "0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0")!
        default:
            throw Attestation.AttestationInternalError.easSchemaContractNotFound(server: server)
        }
    }

    static func getRootKeyUid(server: RPCServer) throws -> Attestation.SchemaUid {
        switch server {
        case .sepolia:
            return "0xee99de42f544fa9a47caaf8d4a4426c1104b6d7a9df7f661f892730f1b5b1e23"
        case .arbitrum:
            return "0xe5c2bfd98a1b35573610b4e5a367bbcb5c736e42508a33fd6046bad63eaf18f9"
        default:
            throw Attestation.AttestationInternalError.rootKeyUidNotFound(server: server)
        }
    }

    static func getEasContract(server: RPCServer) throws -> AlphaWallet.Address {
        switch server {
        case .main:
            return AlphaWallet.Address(string: "0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587")!
        case .arbitrum:
            return AlphaWallet.Address(string: "0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458")!
        case .sepolia:
            return AlphaWallet.Address(string: "0xC2679fBD37d54388Ce493F1DB75320D236e1815e")!
        default:
            throw Attestation.AttestationInternalError.easContractNotFound(server: server)
        }
    }

    static func unzipAttestation(_ zipped: String) throws -> Data {
        //Instead of the usual use of / and +, it might use _ and - instead. So we need to normalize it for parsing
        let normalizedZipped = zipped.replacingOccurrences(of: "_", with: "/").replacingOccurrences(of: "-", with: "+").paddedForBase64Encoded
        //Can't check `zipped.isGzipped`, it's false (sometimes?), but it works, so just don't check
        guard let compressed = Data(base64Encoded: normalizedZipped) else { throw Attestation.AttestationInternalError.unzipAttestationFailed(zipped: zipped) }
        do {
            return try compressed.gunzipped()
        } catch {
            infoLog("[Attestation] Failed to unzip attestation: \(error)")
            throw Attestation.AttestationInternalError.unzipAttestationFailed(zipped: zipped)
        }
    }

    static func checkIsValidAttestationIssuer(attestation: EasAttestation) async throws -> Bool {
        let server = attestation.server
        let keySchemaUid = try getKeySchemaUid(server: server)
        let customResolverContractAddress = try await getSchemaResolverContract(keySchemaUid: keySchemaUid, server: server)
        infoLog("[Attestation] customResolverContractAddress: \(customResolverContractAddress)")

        let signerAddress = attestation.signer
        let isValidated = try await validateSigner(customResolverContractAddress: customResolverContractAddress, signerAddress: signerAddress, server: server)
        infoLog("[Attestation] Signer: \(signerAddress.eip55String) isValidated? \(isValidated)")
        return isValidated
    }

    static func checkEcRecoveredSignerMatches(attestation: EasAttestation) throws -> Bool {
        let address = try ecrecoverSignerAddress(fromAttestation: attestation)
        if let address = address {
            infoLog("[Attestation] Comparing EC-recovered signer: \(address.eip55String) vs attestation.signer: \(attestation.signer)")
            return address == attestation.signer
        } else {
            return false
        }
    }

    static func ecrecoverSignerAddress(fromAttestation attestation: EasAttestation) throws -> AlphaWallet.Address? {
        guard let jsonData = attestation.eip712Representation.data(using: .utf8), let eip712 = try? JSONDecoder().decode(EIP712TypedData.self, from: jsonData) else {
            throw Attestation.AttestationInternalError.generateEip712Failed(attestation: attestation)
        }
        let r = attestation.r
        let s = attestation.s
        let v = attestation.v >= Attestation.vitaliklizeConstant ? attestation.v - Attestation.vitaliklizeConstant : attestation.v
        infoLog("[Attestation] v: \(v)")
        infoLog("[Attestation] r: \(attestation.r) size: \(r.count)")
        infoLog("[Attestation] s: \(attestation.s) size: \(s.count)")
        infoLog("[Attestation] EIP712 digest: \(eip712.digest.hexString)")
        guard let sig: Data = Web3.Utils.marshalSignature(v: v, r: r, s: s) else {
            throw Attestation.AttestationInternalError.reconstructSignatureFailed(attestation: attestation, v: v, r: r, s: s)
        }
        let ethereumAddress = Web3.Utils.hashECRecover(hash: eip712.digest, signature: sig)
        return ethereumAddress.flatMap {
            AlphaWallet.Address(address: $0)
        }
    }

    static func extractAttestationData(attestation: EasAttestation) async throws -> [Attestation.TypeValuePair] {
        let types: [ABIv2.Element.InOut]
        if attestation.schema == "" || attestation.schema == "0x0000000000000000000000000000000000000000000000000000000000000000" || attestation.schema == "0x0" || attestation.schema == "0" {
            types = [
                ABIv2.Element.InOut(name: "eventId", type: ABIv2.Element.ParameterType.string),
                ABIv2.Element.InOut(name: "ticketId", type: ABIv2.Element.ParameterType.string),
                ABIv2.Element.InOut(name: "ticketClass", type: ABIv2.Element.ParameterType.uint(bits: 8)),
                ABIv2.Element.InOut(name: "commitment", type: ABIv2.Element.ParameterType.dynamicBytes),
            ]
            infoLog("[Attestation] schema UID not provided: \(attestation.schema), so we assume stock ticket schema: \(types)")
        } else {
            //EAS's schema here *does* refer to the schema UID
            let schemaRecord = try await getSchemaRecord(keySchemaUid: Attestation.SchemaUid(value: attestation.schema), server: attestation.server)
            infoLog("[Attestation] Found schemaRecord: \(schemaRecord) with schema: \(schemaRecord.schema)")
            guard let localTypes: [ABIv2.Element.InOut] = extractTypesFromSchema(schemaRecord.schema) else {
                throw Attestation.AttestationInternalError.extractAttestationDataFailed(attestation: attestation)
            }
            types = localTypes
        }
        infoLog("[Attestation] types: \(types) data: \(attestation.data)")
        if let decoded = ABIv2Decoder.decode(types: types, data: Data(hex: attestation.data)) {
            //We don't want a dictionary because we want to preserve the order as defined in the schema
            let raw: [(type: ABIv2.Element.InOut, value: AnyObject)] = Array(zip(types, decoded))
            let results: [Attestation.TypeValuePair] = raw.map { each in
                Attestation.TypeValuePair(type: each.type, value: Attestation.TypeValuePair.mapValue(of: each.type.type, for: each.value))
            }
            return results
        } else {
            throw Attestation.AttestationInternalError.extractAttestationDataFailed(attestation: attestation)
        }
    }

    static func extractTypesFromSchema(_ schema: Attestation.Schema) -> [ABIv2.Element.InOut]? {
        let rawList = schema.value
                .components(separatedBy: ",")
                .map {
                    $0.components(separatedBy: " ")
                }
        let result: [ABIv2.Element.InOut] = rawList.compactMap { each in
            guard each.count == 2 else {
                return nil
            }
            let typeString = {
                //See https://github.com/AlphaWallet/alpha-wallet-android/blob/86692639f2bef2acb890524645d80b3910141148/app/src/main/java/com/alphawallet/app/service/AssetDefinitionService.java#L3051
                if each[0].hasPrefix("uint") || each[0].hasPrefix("int") {
                    return "uint256"
                } else if each[0].hasPrefix("bytes") && each[0] != "bytes" {
                    return "bytes32"
                } else {
                    return each[0]
                }
            }()
            let name = each[1]
            if let type = try? ABIv2TypeParser.parseTypeString(typeString) {
                return ABIv2.Element.InOut(name: name, type: type)
            } else {
                infoLog("[Attestation] can't parse type: \(typeString) from schema: \(schema)")
                return nil
            }
        }
        if result.count == rawList.count {
            return result
        } else {
            return nil
        }
    }

    static func validateSigner(customResolverContractAddress: AlphaWallet.Address, signerAddress: AlphaWallet.Address, server: RPCServer) async throws -> Bool {
        let rootKeyUID = try getRootKeyUid(server: server)
        let abiString = """
                        [
                          {
                            "constant": false,
                            "inputs": [
                              {"name": "rootKeyUID","type": "bytes32"},
                              {"name": "signerAddress","type": "address"}
                            ],
                            "name": "validateSignature",
                            "outputs": [{"name": "", "type": "bool"}],
                            "type": "function"
                          }
                        ]
                        """
        let parameters = [rootKeyUID.value, EthereumAddress(address: signerAddress)] as [AnyObject]
        let result: [String: Any]
        do {
            result = try await Attestation.callSmartContract(server, customResolverContractAddress, "validateSignature", abiString, parameters)
        } catch {
            infoLog("[Attestation] call validateSignature() failure: \(error)")
            throw Attestation.AttestationInternalError.validateSignatureFailed(server: server, signerAddress: signerAddress)
        }
        let boolResult = result["0"] as? Bool
        if let result = boolResult {
            return result
        } else {
            infoLog("[Attestation] can't extract signer validation result (with `validateSignature()`) as bool: \(String(describing: result["0"]))")
            throw Attestation.AttestationInternalError.validateSignatureFailed(server: server, signerAddress: signerAddress)
        }
    }

    static func getSchemaResolverContract(keySchemaUid: Attestation.SchemaUid, server: RPCServer) async throws -> AlphaWallet.Address {
        let schemaRecord = try await getSchemaRecord(keySchemaUid: keySchemaUid, server: server)
        return schemaRecord.resolver
    }

    //TODO improve caching. Current implementation doesn't reduce duplicate inflight calls or failures
    static var cachedSchemaRecords: [String: SchemaRecord] = .init()
    //Schema the schema pointed to by a schema UID can't change, we can hardcode some
    private static var hardcodedSchemaRecords: [Attestation.SchemaUid: SchemaRecord] = [
        //KeyDecription is verbatim from the schema definition
        Attestation.SchemaUid("0x4455598d3ec459c4af59335f7729fea0f50ced46cb1cd67914f5349d44142ec1"): SchemaRecord(uid: Attestation.SchemaUid("0x4455598d3ec459c4af59335f7729fea0f50ced46cb1cd67914f5349d44142ec1"), resolver: AlphaWallet.Address(string: "0x0Ed88b8AF0347fF49D7e09AA56bD5281165225B6")!, revocable: true, schema: Attestation.Schema("string KeyDecription,bytes ASN1Key,bytes PublicKey")),
        "0x5f0437f7c1db1f8e575732ca52cc8ad899b3c9fe38b78b67ff4ba7c37a8bf3b4": SchemaRecord(uid: Attestation.SchemaUid("0x5f0437f7c1db1f8e575732ca52cc8ad899b3c9fe38b78b67ff4ba7c37a8bf3b4"), resolver: AlphaWallet.Address(string: "0xF0768c269b015C0A246157c683f9377eF571dCD3")!, revocable: true, schema: "string KeyDescription,bytes ASN1Key,bytes PublicKey"),
        "0x7f6fb09beb1886d0b223e9f15242961198dd360021b2c9f75ac879c0f786cafd": SchemaRecord(uid: "0x7f6fb09beb1886d0b223e9f15242961198dd360021b2c9f75ac879c0f786cafd", resolver: Constants.nullAddress, revocable: true, schema: "string eventId,string ticketId,uint8 ticketClass,bytes commitment"),
        "0x0630f3342772bf31b669bdbc05af0e9e986cf16458f292dfd3b57564b3dc3247": SchemaRecord(uid: "0x0630f3342772bf31b669bdbc05af0e9e986cf16458f292dfd3b57564b3dc3247", resolver: Constants.nullAddress, revocable: true, schema: "string devconId,string ticketIdString,uint8 ticketClass,bytes commitment"),
        "0xba8aaaf91d1f63d998fb7da69449d9a314bef480e9555710c77d6e594e73ca7a": SchemaRecord(uid: "0xba8aaaf91d1f63d998fb7da69449d9a314bef480e9555710c77d6e594e73ca7a", resolver: Constants.nullAddress, revocable: true, schema: "string eventId,string ticketId,uint8 ticketClass,bytes commitment,string scriptUri"),
    ]

    static func getSchemaRecord(keySchemaUid: Attestation.SchemaUid, server: RPCServer) async throws -> SchemaRecord {
        if let hardcoded = hardcodedSchemaRecords[keySchemaUid] {
            infoLog("[Attestation] Using hardcoded schema record and skipping JSON-RPC call for keySchemaUid: \(keySchemaUid) returning schemaRecord: \(hardcoded)")
            return hardcoded
        }
        let registryContract = try getEasSchemaContract(server: server)
        let abiString = """
                        [
                          {
                            "constant": false,
                            "inputs": [
                              {"name": "keySchemaUid", "type": "bytes32"},
                            ],
                            "name": "getSchema",
                            "outputs": [
                                {
                                    "components": [
                                        {"name": "uid", "type": "bytes32"},
                                        {"name": "resolver", "type": "address"},
                                        {"name": "revocable", "type": "bool"},
                                        {"name": "schema", "type": "string"},
                                    ],
                                    "name": "",
                                    "type": "tuple",
                                }
                            ],
                            "type": "function"
                          }
                        ]
                        """
        let parameters = [keySchemaUid.value] as [AnyObject]
        let functionName = "getSchema"
        let cacheKey = "\(registryContract).\(functionName) \(parameters) \(server.chainID) \(abiString)"
        if let cached = cachedSchemaRecords[cacheKey] {
            return cached
        }
        let result: [String: Any]
        do {
            result = try await Attestation.callSmartContract(server, registryContract, functionName, abiString, parameters)
        } catch {
            //TODO figure out why this fails on device, but works on simulator
            throw Attestation.AttestationInternalError.schemaRecordNotFound(keySchemaUid: keySchemaUid, server: server)
        }
        if let uidString = ((result["0"] as? [AnyObject])?[0] as? Data)?.toHexString(),
           let resolver = (result["0"] as? [AnyObject])?[1] as? EthereumAddress,
           let revocable = (result["0"] as? [AnyObject])?[2] as? Bool,
           let schema = (result["0"] as? [AnyObject])?[3] as? String {
            let uid = Attestation.SchemaUid(value: uidString)
            let record = SchemaRecord(uid: uid, resolver: AlphaWallet.Address(address: resolver), revocable: revocable, schema: Attestation.Schema(value: schema))
            cachedSchemaRecords[cacheKey] = record
            return record
        } else {
            infoLog("[Attestation] can't convert to schema record: \(String(describing: result["0"])) for keySchemaUid: \(keySchemaUid)")
            throw Attestation.AttestationInternalError.schemaRecordNotFound(keySchemaUid: keySchemaUid, server: server)
        }
    }
}

extension EasAttestation {
    var server: RPCServer {
        return RPCServer(chainID: chainId)
    }
}

fileprivate struct Constants {
    static let nullAddress = AlphaWallet.Address(uncheckedAgainstNullAddress: "0x0000000000000000000000000000000000000000")!
}

fileprivate extension Data {
    //TODO: Duplicated here. Move to Core
    var hexString: String {
        return map({ String(format: "%02x", $0) }).joined()
    }
}

fileprivate extension String {
    public var dropDataPrefix: String {
        if count > 5 && substring(with: 0..<5) == "data." {
            return String(dropFirst(5))
        }
        return self
    }
}
