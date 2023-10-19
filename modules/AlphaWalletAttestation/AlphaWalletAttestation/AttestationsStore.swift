// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import Foundation
import AlphaWalletAddress

fileprivate typealias AttestationsStorage = [AlphaWallet.Address: [Attestation]]

public class AttestationsStore {
    static private let filename: String = "attestations.json"
    static private var fileUrl: URL = {
        let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        return documentsDirectory.appendingPathComponent(filename)
    }()

    @Published public var attestations: [Attestation]
    private let wallet: AlphaWallet.Address

    public init(wallet: AlphaWallet.Address) {
        self.wallet = wallet
        self.attestations = functional.readAttestations(forWallet: wallet, from: Self.fileUrl)
    }

    public static func allAttestations() -> [Attestation] {
        return functional.readAttestations(from: fileUrl).flatMap { $0.value }
    }

    //TODO we pass in `identifyingFieldNames` and `collectionIdFieldNames` to compare because this code is in AlphaWalletAttestation and we don't have access to TokenScript here. Leaky, or good?
    public func addAttestation(_ attestation: Attestation, forWallet address: AlphaWallet.Address, collectionIdFieldNames: [String], identifyingFieldNames: [String]) async -> Bool {
        var allAttestations = functional.readAttestations(from: Self.fileUrl)
        do {
            var attestationsForWallet: [Attestation] = allAttestations[address, default: []]
            if attestations.contains(attestation) {
                infoLog("[Attestation] Attestation already exist. Skipping")
                return false
            } else if let attestationToReplace = await findAttestationWithSameIdentity(attestation, collectionIdFieldNames: collectionIdFieldNames, identifyingFieldNames: identifyingFieldNames, inAttestations: attestationsForWallet) {
                attestationsForWallet = functional.arrayReplacingAttestation(array: attestationsForWallet, old: attestationToReplace, replacement: attestation)
                allAttestations[address] = attestationsForWallet
                try saveAttestations(attestations: allAttestations)
                attestations = attestationsForWallet
                infoLog("[Attestation] Imported attestation and replaced previous")
                return true
            } else {
                attestationsForWallet.append(attestation)
                allAttestations[address] = attestationsForWallet
                try saveAttestations(attestations: allAttestations)
                attestations = attestationsForWallet
                infoLog("[Attestation] Imported attestation")
                return true
            }
        } catch {
            errorLog("[Attestation] failed to encode attestations while adding attestation to: \(Self.fileUrl.absoluteString) error: \(error)")
            return false
        }
    }

    private func findAttestationWithSameIdentity(_ attestation: Attestation, collectionIdFieldNames: [String], identifyingFieldNames: [String], inAttestations attestations: [Attestation]) async -> Attestation? {
        let attestationIdFields: [AttestationAttribute] = identifyingFieldNames.map { AttestationAttribute(label: $0, path: $0) }
        let collectionIdFields: [AttestationAttribute] = collectionIdFieldNames.map { AttestationAttribute(label: $0, path: $0) }
        guard !attestationIdFields.isEmpty && !collectionIdFields.isEmpty else { return nil }
        let identityForNewAttestation = functional.computeIdentity(forAttestation: attestation, collectionIdFields: collectionIdFields, attestationIdFields: attestationIdFields)
        for each in attestations {
            let identityForExistingAttestation = functional.computeIdentity(forAttestation: each, collectionIdFields: collectionIdFields, attestationIdFields: attestationIdFields)
            if identityForExistingAttestation == identityForNewAttestation {
                return each
            }
        }
        return nil
    }

    public func removeAttestation(_ attestation: Attestation, forWallet address: AlphaWallet.Address) {
        var allAttestations = functional.readAttestations(from: Self.fileUrl)
        do {
            var attestationsForWallet: [Attestation] = allAttestations[address, default: []]
            attestationsForWallet = attestationsForWallet.filter { $0 != attestation }
            allAttestations[address] = attestationsForWallet

            try saveAttestations(attestations: allAttestations)
            attestations = attestationsForWallet
        } catch {
            errorLog("[Attestation] failed to encode attestations while removing attestation to: \(Self.fileUrl.absoluteString) error: \(error)")
        }
    }

    private func saveAttestations(attestations: AttestationsStorage) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(attestations)
        try data.write(to: Self.fileUrl)
    }

    enum functional {}
}

fileprivate extension AttestationsStore.functional {
    static func readAttestations(from fileUrl: URL) -> AttestationsStorage {
        do {
            let data = try Data(contentsOf: fileUrl)
            let decoder = JSONDecoder()
            let allAttestations = try decoder.decode(AttestationsStorage.self, from: data)
            return allAttestations
        } catch {
            return AttestationsStorage()
        }
    }

    static func readAttestations(forWallet address: AlphaWallet.Address, from fileUrl: URL) -> [Attestation] {
        let allAttestations = readAttestations(from: fileUrl)
        let result: [Attestation] = allAttestations[address, default: []]
        return result
    }

    static func arrayReplacingAttestation(array: [Attestation], old: Attestation, replacement: Attestation) -> [Attestation] {
        var result = array
        if let index = result.firstIndex(of: old) {
            result[index] = replacement
        }
        return result
    }

    //TODO better in AlphaWalletTokenScript. But we can't move it due to dependency
    static func computeIdentity(forAttestation attestation: Attestation, collectionIdFields: [AttestationAttribute], attestationIdFields: [AttestationAttribute]) -> String {
        let idFieldsData = Attestation.resolveAttestationAttributes(forAttestation: attestation, withAttestationFields: attestationIdFields)
        let collectionId = Attestation.computeAttestationCollectionId(forAttestation: attestation, collectionIdFields: collectionIdFields)
        let identity = String(attestation.chainId) + collectionId + idFieldsData.map { $0.value.stringValue }.joined()
        //We should hash too, but exclude it because it introduces a dependency on CryptoSwift and we don't need it as we can compare pre-hash
        return identity
    }
}
