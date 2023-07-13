// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import Gzip
//TODO remove AlphaWalletFoundation if possible, It's only needed for `EIP712TypedData`. At this point, it's too tedious to move `EIP712TypedData` out to `AlphaWalletWeb3` because there is a circular dependency
import AlphaWalletFoundation
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
        case cannotEncode(AssetInternalValue)
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
    typealias SchemaUid = String
    public typealias ChainId = Int

    //Redefine here so reduce dependencies
    static var vitaliklizeConstant: UInt8 = 27

    public static var callSmartContract: ((ChainId, AlphaWallet.Address, String, String, [AnyObject]) async throws -> [String: Any])!
    public static var isLoggingEnabled = false

    public struct TypeValuePair: Codable, Hashable {
        public let type: ABIv2.Element.InOut
        public let value: AttestationPropertyValue

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
        case validateSignatureFailed(chainId: ChainId, signerAddress: AlphaWallet.Address, error: AttestationInternalError)
        case schemaRecordNotFound(ChainId, AttestationInternalError)
        case chainNotSupported(chainId: ChainId, error: AttestationInternalError)
        case ecRecoveredSignerDoesNotMatch
        case parseAttestationUrlFailed(String)
    }

    enum AttestationInternalError: Error {
        case unzipAttestationFailed(zipped: String)
        case decodeAttestationArrayStringFailed(zipped: String)
        case decodeEasAttestationFailed(zipped: String)
        case extractAttestationDataFailed(attestation: EasAttestation)
        case validateSignatureFailed(chainId: ChainId, signerAddress: AlphaWallet.Address)
        case generateEip712Failed(attestation: EasAttestation)
        case reconstructSignatureFailed(attestation: EasAttestation, v: UInt8, r: [UInt8], s: [UInt8])
        case schemaRecordNotFound(keySchemaUid: Attestation.SchemaUid, chainId: ChainId)
        case keySchemaUidNotFound(chainId: ChainId)
        case easSchemaContractNotFound(chainId: ChainId)
        case rootKeyUidNotFound(chainId: ChainId)
        case easContractNotFound(chainId: ChainId)
    }

    public let data: [TypeValuePair]
    public let source: String
    private let easAttestation: EasAttestation
    public let isValidAttestationIssuer: Bool

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
    public var chainId: Int { easAttestation.chainId }
    //TODO not hardcode
    public var name: String { "EAS Attestation" }

    private init(data: [TypeValuePair], easAttestation: EasAttestation, isValidAttestationIssuer: Bool, source: String) {
        self.data = data
        self.easAttestation = easAttestation
        self.isValidAttestationIssuer = isValidAttestationIssuer
        self.source = source
    }

    public static func extract(fromUrlString urlString: String) async throws -> Attestation {
        if let url = URL(string: urlString),
           let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
           let components = Optional(fragment.split(separator: "=", maxSplits: 1)),
           components.first == "attestation" {
            let encodedAttestation = components[1]
            let attestation = try await Attestation.extract(fromEncodedValue: String(encodedAttestation), source: urlString)
            return attestation
        } else if let url = URL(string: urlString),
                  let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = urlComponents.queryItems,
                  let ticketItem = queryItems.first(where: { $0.name == "ticket" }), let encodedAttestation = ticketItem.value {
            let replacedAttestationValue = encodedAttestation.replacingOccurrences(of: "_", with: "/").replacingOccurrences(of: "-", with: "+")
            let attestation = try await Attestation.extract(fromEncodedValue: String(replacedAttestationValue), source: urlString)
            return attestation
        } else {
            throw AttestationError.parseAttestationUrlFailed(urlString)
        }
    }

    public static func extract(fromEncodedValue value: String, source: String) async throws -> Attestation {
        do {
            return try await _extractFromEncoded(value, source: source)
        } catch let error as AttestationInternalError {
            //Wraps with public errors
            switch error {
            case .unzipAttestationFailed, .decodeAttestationArrayStringFailed, .decodeEasAttestationFailed, .extractAttestationDataFailed:
                throw AttestationError.extractAttestationFailed(error)
            case .validateSignatureFailed(let chainId, let signerAddress):
                throw AttestationError.validateSignatureFailed(chainId: chainId, signerAddress: signerAddress, error: error)
            case .generateEip712Failed, .reconstructSignatureFailed:
                throw AttestationError.ecRecoverFailed(error)
            case .schemaRecordNotFound(_, let chainId):
                throw AttestationError.schemaRecordNotFound(chainId, error)
            case .keySchemaUidNotFound(let chainId), .easSchemaContractNotFound(let chainId), .rootKeyUidNotFound(let chainId), .easContractNotFound(let chainId):
                throw AttestationError.chainNotSupported(chainId: chainId, error: error)
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
        verboseLog("[Attestation] Decompressed attestation: \(attestationArrayString)")

        guard let attestationArrayData = attestationArrayString.data(using: .utf8), let attestationFromArrayString = try? JSONDecoder().decode(EasAttestationFromArrayString.self, from: attestationArrayData) else {
            throw AttestationInternalError.decodeEasAttestationFailed(zipped: scannedValue)
        }
        let attestation = EasAttestation(fromAttestationArrayString: attestationFromArrayString)

        let isEcRecoveredSignerMatches = try functional.checkEcRecoveredSignerMatches(attestation: attestation)
        verboseLog("[Attestation] ec-recovered signer matches: \(isEcRecoveredSignerMatches)")
        guard isEcRecoveredSignerMatches else {
            throw AttestationError.ecRecoveredSignerDoesNotMatch
        }

        let isValidAttestationIssuer = try await functional.checkIsValidAttestationIssuer(attestation: attestation)
        verboseLog("[Attestation] is signer verified: \(isValidAttestationIssuer)")

        let results: [TypeValuePair] = try await functional.extractAttestationData(attestation: attestation)
        verboseLog("[Attestation] decoded attestation data: \(results) isValidAttestationIssuer: \(isValidAttestationIssuer)")

        return Attestation(data: results, easAttestation: attestation, isValidAttestationIssuer: isValidAttestationIssuer, source: source)
    }

    enum functional {}
}

//For testing
extension Attestation.functional {
    internal static func extractTypesFromSchemaForTesting(_ schema: String) -> [ABIv2.Element.InOut]? {
        return extractTypesFromSchema(schema)
    }
}

fileprivate extension Attestation.functional {
    struct SchemaRecord {
        let uid: String
        let resolver: AlphaWallet.Address
        let revocable: Bool
        let schema: String
    }

    static func getKeySchemaUid(chainId: Attestation.ChainId) throws -> Attestation.SchemaUid {
        switch chainId {
        case 11155111:
            return "0x4455598d3ec459c4af59335f7729fea0f50ced46cb1cd67914f5349d44142ec1"
        default:
            throw Attestation.AttestationInternalError.keySchemaUidNotFound(chainId: chainId)
        }
    }

    static func getEasSchemaContract(chainId: Attestation.ChainId) throws -> AlphaWallet.Address {
        switch chainId {
        case 1:
            return AlphaWallet.Address(string: "0xA7b39296258348C78294F95B872b282326A97BDF")!
        case 42161:
            return AlphaWallet.Address(string: "0xA310da9c5B885E7fb3fbA9D66E9Ba6Df512b78eB")!
        case 11155111:
            return AlphaWallet.Address(string: "0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0")!
        default:
            throw Attestation.AttestationInternalError.easSchemaContractNotFound(chainId: chainId)
        }
    }

    static func getRootKeyUid(chainId: Attestation.ChainId) throws -> Attestation.SchemaUid {
        switch chainId {
        case 11155111:
            return "0xee99de42f544fa9a47caaf8d4a4426c1104b6d7a9df7f661f892730f1b5b1e23"
        default:
            throw Attestation.AttestationInternalError.rootKeyUidNotFound(chainId: chainId)
        }
    }

    static func getEasContract(chainId: Attestation.ChainId) throws -> AlphaWallet.Address {
        switch chainId {
        case 1:
            return AlphaWallet.Address(string: "0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587")!
        case 42161:
            return AlphaWallet.Address(string: "0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458")!
        case 11155111:
            return AlphaWallet.Address(string: "0xC2679fBD37d54388Ce493F1DB75320D236e1815e")!
        default:
            throw Attestation.AttestationInternalError.easContractNotFound(chainId: chainId)
        }
    }

    static func unzipAttestation(_ zipped: String) throws -> Data {
        //Can't check `zipped.isGzipped`, it's false (sometimes?), but it works, so just don't check
        guard let compressed = Data(base64Encoded: zipped) else {
            throw Attestation.AttestationInternalError.unzipAttestationFailed(zipped: zipped)
        }
        do {
            return try compressed.gunzipped()
        } catch {
            verboseLog("[Attestation] Failed to unzip attestation: \(error)")
            throw Attestation.AttestationInternalError.unzipAttestationFailed(zipped: zipped)
        }
    }

    static func checkIsValidAttestationIssuer(attestation: EasAttestation) async throws -> Bool {
        let chainId = attestation.chainId
        let keySchemaUid = try getKeySchemaUid(chainId: chainId)
        let customResolverContractAddress = try await getSchemaResolverContract(keySchemaUid: keySchemaUid, chainId: chainId)
        verboseLog("[Attestation] customResolverContractAddress: \(customResolverContractAddress)")

        let signerAddress = attestation.signer
        let isValidated = try await validateSigner(customResolverContractAddress: customResolverContractAddress, signerAddress: signerAddress, chainId: chainId)
        verboseLog("[Attestation] Signer: \(signerAddress.eip55String) isValidated? \(isValidated)")
        return isValidated
    }

    static func checkEcRecoveredSignerMatches(attestation: EasAttestation) throws -> Bool {
        let address = try ecrecoverSignerAddress(fromAttestation: attestation)
        if let address = address {
            verboseLog("[Attestation] Comparing EC-recovered signer: \(address.eip55String) vs attestation.signer: \(attestation.signer)")
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
        verboseLog("[Attestation] v: \(v)")
        verboseLog("[Attestation] r: \(attestation.r) size: \(r.count)")
        verboseLog("[Attestation] s: \(attestation.s) size: \(s.count)")
        verboseLog("[Attestation] EIP712 digest: \(eip712.digest.hexString)")
        guard let sig: Data = Web3.Utils.marshalSignature(v: v, r: r, s: s) else {
            throw Attestation.AttestationInternalError.reconstructSignatureFailed(attestation: attestation, v: v, r: r, s: s)
        }
        let ethereumAddress = Web3.Utils.hashECRecover(hash: eip712.digest, signature: sig)
        return ethereumAddress.flatMap { AlphaWallet.Address(address: $0) }
    }

    static func extractAttestationData(attestation: EasAttestation) async throws -> [Attestation.TypeValuePair] {
        let schemaRecord = try await getSchemaRecord(keySchemaUid: attestation.schema, chainId: attestation.chainId)
        verboseLog("[Attestation] Found schemaRecord: \(schemaRecord) with schema: \(schemaRecord.schema)")
        guard let types: [ABIv2.Element.InOut] = extractTypesFromSchema(schemaRecord.schema) else {
            throw Attestation.AttestationInternalError.extractAttestationDataFailed(attestation: attestation)
        }
        verboseLog("[Attestation] types: \(types) data: \(attestation.data)")
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

    static func extractTypesFromSchema(_ schema: String) -> [ABIv2.Element.InOut]? {
        let rawList = schema
            .components(separatedBy: ",")
            .map { $0.components(separatedBy: " ") }
        let result: [ABIv2.Element.InOut] = rawList.compactMap { each in
            guard each.count == 2 else { return nil }
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
                verboseLog("[Attestation] can't parse type: \(typeString) from schema: \(schema)")
                return nil
            }
        }
        if result.count == rawList.count {
            return result
        } else {
            return nil
        }
    }

    static func validateSigner(customResolverContractAddress: AlphaWallet.Address, signerAddress: AlphaWallet.Address, chainId: Attestation.ChainId) async throws -> Bool {
        let rootKeyUID = try getRootKeyUid(chainId: chainId)
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
        let parameters = [rootKeyUID, EthereumAddress(address: signerAddress)] as [AnyObject]
        let result: [String: Any]
        do {
            result = try await Attestation.callSmartContract(chainId, customResolverContractAddress, "validateSignature", abiString, parameters)
        } catch {
            throw Attestation.AttestationInternalError.validateSignatureFailed(chainId: chainId, signerAddress: signerAddress)
        }
        let boolResult = result["0"] as? Bool
        if let result = boolResult {
            return result
        } else {
            verboseLog("[Attestation] can't extract signer validation result (with `validateSignature()`) as bool: \(String(describing: result["0"]))")
            throw Attestation.AttestationInternalError.validateSignatureFailed(chainId: chainId, signerAddress: signerAddress)
        }
    }

    static func getSchemaResolverContract(keySchemaUid: Attestation.SchemaUid, chainId: Attestation.ChainId) async throws -> AlphaWallet.Address {
        let schemaRecord = try await getSchemaRecord(keySchemaUid: keySchemaUid, chainId: chainId)
        return schemaRecord.resolver
    }

    //TODO improve caching. Current implementation doesn't reduce duplicate inflight calls or failures
    static var cachedSchemaRecords: [String: SchemaRecord] = .init()
    static func getSchemaRecord(keySchemaUid: Attestation.SchemaUid, chainId: Attestation.ChainId) async throws -> SchemaRecord {
        let registryContract = try getEasSchemaContract(chainId: chainId)
        let abiString = """
                        [ 
                          { 
                            "constant": false, 
                            "inputs": [ 
                              {"keySchemaUid": "","type": "bytes32"}, 
                            ], 
                            "name": "getSchema", 
                            "outputs": [{"components":
                                [
                                    {"name": "uid", "type": "bytes32"},
                                    {"name": "resolver", "type": "address"}, 
                                    {"name": "revocable", "type": "bool"}, 
                                    {"name": "schema", "type": "string"},
                                ],
                                "name": "",
                                "type": "tuple",
                            }],
                            "type": "function" 
                          },
                        ]
                        """
        let parameters = [keySchemaUid] as [AnyObject]
        let functionName = "getSchema"
        let cacheKey = "\(registryContract).\(functionName) \(parameters) \(chainId) \(abiString)"
        if let cached = cachedSchemaRecords[cacheKey] {
            return cached
        }
        let result: [String: Any]
        do {
            result = try await Attestation.callSmartContract(chainId, registryContract, functionName, abiString, parameters)
        } catch {
            throw Attestation.AttestationInternalError.schemaRecordNotFound(keySchemaUid: keySchemaUid, chainId: chainId)
        }
        if let uid = ((result["0"] as? [AnyObject])?[0] as? Data)?.toHexString(),
           let resolver = (result["0"] as? [AnyObject])?[1] as? EthereumAddress,
           let revocable = (result["0"] as? [AnyObject])?[2] as? Bool,
           let schema = (result["0"] as? [AnyObject])?[3] as? String {
            let record = SchemaRecord(uid: uid, resolver: AlphaWallet.Address(address: resolver), revocable: revocable, schema: schema)
            cachedSchemaRecords[cacheKey] = record
            return record
        } else {
            verboseLog("[Attestation] can't convert to schema record: \(String(describing: result["0"])) for keySchemaUid: \(keySchemaUid)")
            throw Attestation.AttestationInternalError.schemaRecordNotFound(keySchemaUid: keySchemaUid, chainId: chainId)
        }
    }
}
