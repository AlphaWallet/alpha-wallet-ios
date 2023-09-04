// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAttestation
import AlphaWalletFoundation
import AlphaWalletLogger
import Alamofire

class SmartLayerPass {
    static let typeFieldName = "orgId"

    private func authHeaderValue(forDomain domain: String) -> String? {
        if domain == "www.smartlayer.network" || domain == "smartlayer.network" {
            let value = Constants.Credentials.smartLayerPassAuthProd
            if value.isEmpty {
                return nil
            } else {
                return value
            }
        } else if domain == "smart-layer.vercel.app" {
            let value = Constants.Credentials.smartLayerPassAuthDev
            if value.isEmpty {
                return nil
            } else {
                return value
            }
        } else {
            return nil
        }
    }

    private func webApiDomain(forDomain domain: String) -> String? {
        if domain == "www.smartlayer.network" || domain == "smartlayer.network" {
            return "backend.smartlayer.network"
        } else if domain == "smart-layer.vercel.app" {
            return "d2a5tt41o5qmyt.cloudfront.net"
        } else {
            return nil
        }
    }

    func handleAddedAttestation(_ attestation: Attestation, attestationStore: AttestationsStore) {
        let optionalEventId = attestation.stringProperty(withName: Self.typeFieldName)
        guard let eventId = optionalEventId, eventId == "SMARTLAYER" else {
            infoLog("[SmartLayerPass] Not a Smart Layer pass attestation, as eventId: \(String(describing: optionalEventId)) so no-op")
            return
        }
        guard !attestation.server.isTestnet else {
            infoLog("[SmartLayerPass] Smart Layer pass attestation is on testnet: \(attestation.server), so no-op")
            return
        }
        guard let domain = functional.extractSmartLayerPassDomain(fromAttestation: attestation) else {
            infoLog("[SmartLayerPass] Not a Smart Layer pass attestation because domain extracted doesn't match expected, so no-op")
            return
        }
        guard let authHeaderValue = authHeaderValue(forDomain: domain) else {
            infoLog("[SmartLayerPass] not found expected auth header value configured for domain: \(domain)")
            return
        }
        guard let webApiDomain = webApiDomain(forDomain: domain) else {
            infoLog("[SmartLayerPass] not found expected web API domain configured for domain: \(domain)")
            return
        }
        guard let encodedAttestation = functional.extractSignedToken(fromUrlString: attestation.source) else {
            infoLog("[SmartLayerPass] not found encoded attestation in source of attestation: \(attestation.source)")
            return
        }

        let attestations = functional.filterAttestations(attestationStore.attestations, matchingDomain: domain)
        let attestationsCount = attestations.count

        let parameters: [String: Any] = [
            "signedToken": encodedAttestation,
            "installedPassedInAw": attestationsCount
        ]
        let headers: HTTPHeaders = [
            "accept": "*/*",
            "Authorization": authHeaderValue,
            "Content-Type": "application/json",
        ]
        let url = "https://\(webApiDomain)/passes/pass-installed-in-aw"
        Task {
            let response = await AF.request(url, method: .put, parameters: parameters, encoding: JSONEncoding.default, headers: headers).serializingData().response
            if let data = response.data, let response1 = response.response {
                let string = String(data: data, encoding: .utf8)
                infoLog("[SmartLayerPass] Clocking \(url) with count: \(attestationsCount) result: \(String(describing: string)) status code: \(response1.statusCode)")
            } else {
                infoLog("[SmartLayerPass] Clocking \(url) with count: \(attestationsCount) error: \(String(describing: response.error))")
            }
        }
    }

    enum functional {
    }
}

fileprivate extension SmartLayerPass.functional {
    static func extractSmartLayerPassDomain(fromAttestation attestation: Attestation) -> String? {
        guard let url = URL(string: attestation.source) else { return nil }
        guard let domain = url.host else { return nil }
        if ["www.smartlayer.network", "smartlayer.network", "smart-layer.vercel.app"].contains(domain) {
            return domain
        } else {
            return nil
        }
    }

    static func filterAttestations(_ attestations: [Attestation], matchingDomain: String) -> [Attestation] {
        return attestations.filter {
            let domain = SmartLayerPass.functional.extractSmartLayerPassDomain(fromAttestation: $0)
            return matchingDomain == domain
        }
    }

    static func extractSignedToken(fromUrlString urlString: String) -> String? {
        if let url = URL(string: urlString),
           let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
           let components = Optional(fragment.split(separator: "=", maxSplits: 1)),
           components.first == "attestation" {
            return String(components[1])
        } else if let url = URL(string: urlString),
                  let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = urlComponents.queryItems,
                  let ticketItem = queryItems.first(where: { $0.name == "ticket" }) {
            return ticketItem.value
        } else {
            return nil
        }
    }
}