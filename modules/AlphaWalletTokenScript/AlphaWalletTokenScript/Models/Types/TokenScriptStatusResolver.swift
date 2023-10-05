// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress
import AlphaWalletAttestation
import PromiseKit

public class TokenScriptStatusResolver {
    private let backingStore: AssetDefinitionBackingStore
    private let signatureVerifier: TokenScriptSignatureVerifieble

    init(backingStore: AssetDefinitionBackingStore, signatureVerifier: TokenScriptSignatureVerifieble) {
        self.backingStore = backingStore
        self.signatureVerifier = signatureVerifier
    }

    public func computeTokenScriptStatus(forContract contract: AlphaWallet.Address, xmlString: String, isOfficial: Bool) -> Promise<TokenLevelTokenScriptDisplayStatus> {
        if backingStore.hasConflictingFile(forContract: contract) {
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .tokenScriptType2ConflictingFiles, reason: .conflictWithAnotherFile))
        }
        //TODO not support tracking outdated TokenScript files anymore?
        //if backingStore.hasOutdatedTokenScript(forContract: contract) {
        //    return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .tokenScriptType2OldSchemaVersion, reason: .oldTokenScriptVersion))
        //}
        if xmlString.nilIfEmpty == nil {
            return .value(.type0NoTokenScript)
        }

        switch XMLHandler.checkTokenScriptSchema(xmlString) {
        case .supportedTokenScriptVersion:
            return firstly {
                verificationType(forXml: xmlString)
            }.then { [backingStore] verificationStatus -> Promise<TokenLevelTokenScriptDisplayStatus> in
                return Promise { seal in
                    backingStore.writeCacheTokenScriptSignatureVerificationType(verificationStatus, forContract: contract, forXmlString: xmlString)

                    switch verificationStatus {
                    case .verified(let domainName):
                        seal.fulfill(.type1GoodTokenScriptSignatureGoodOrOptional(isDebugMode: !isOfficial, isSigned: true, validatedDomain: domainName, error: .tokenScriptType1SupportedAndSigned))
                    case .verificationFailed:
                        seal.fulfill(.type2BadTokenScript(isDebugMode: !isOfficial, error: .tokenScriptType2InvalidSignature, reason: .invalidSignature))
                    case .notCanonicalizedAndNotSigned:
                        //But should always be debug mode because we can't have a non-canonicalized XML from the official repo
                        seal.fulfill(.type1GoodTokenScriptSignatureGoodOrOptional(isDebugMode: !isOfficial, isSigned: false, validatedDomain: nil, error: .tokenScriptType1SupportedNotCanonicalizedAndUnsigned))
                    }
                }
            }
        case .unsupportedTokenScriptVersion(let isOld):
            if isOld {
                return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .custom("type 2 or bad? Mismatch version. Old version"), reason: .oldTokenScriptVersion))
            } else {
                preconditionFailure("Not expecting an unsupported and new version of TokenScript schema here")
                return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .custom("type 2 or bad? Mismatch version. Unknown schema"), reason: nil))
            }
        case .unknownXml:
            preconditionFailure("Not expecting an unknown XML here when checking TokenScript schema")
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .custom("unknown. Maybe empty invalid? Doesn't even include something that might be our schema"), reason: nil))
        case .others:
            preconditionFailure("Not expecting an unknown error when checking TokenScript schema")
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, error: .custom("Not XML?"), reason: nil))
        }
    }

    public func computeTokenScriptStatus(forAttestation attestation: Attestation, xmlString: String) -> Promise<TokenLevelTokenScriptDisplayStatus> {
        //TODO attestations+TokenScript to implement computeTokenScriptStatus. Note that this is about the TokenScript file. Not the attestation issuer
        return Promise { _ in }
    }

    private func verificationType(forXml xmlString: String) -> PromiseKit.Promise<TokenScriptSignatureVerificationType> {
        if let cachedVerificationType = backingStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString) {
            return .value(cachedVerificationType)
        } else {
            return signatureVerifier.verificationType(forXml: xmlString)
        }
    }
}
