//
//  AssetDefinitionNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 19.12.2022.
//

import Foundation
import Combine
import AlphaWalletCore

public class AssetDefinitionNetworking {
    private let networkService: NetworkService

    public init(networkService: NetworkService) {
        self.networkService = networkService
    }

    public enum Response {
        case unmodified
        case error
        case xml(String)
    }

    public func fetchXml(request: GetXmlFileRequest) -> AnyPublisher<AssetDefinitionNetworking.Response, Never> {
        return networkService
            .dataTaskPublisher(request)
            .map { data -> AssetDefinitionNetworking.Response in
                if data.response.statusCode == 304 {
                    return .unmodified
                } else if data.response.statusCode == 406 {
                    return .error
                } else if data.response.statusCode == 404 {
                    return .error
                } else if data.response.statusCode == 200 {
                    if let xml = String(data: data.data, encoding: .utf8).nilIfEmpty {
                        return .xml(xml)
                    } else {
                        return .error
                    }
                }
                return .error
            }.replaceError(with: .error)
            .share()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

extension AssetDefinitionNetworking {
    public struct GetXmlFileRequest: URLRequestConvertible, Hashable {
        let url: URL
        let lastModifiedDate: Date?

        public init(url: URL, lastModifiedDate: Date?) {
            self.url = url
            self.lastModifiedDate = lastModifiedDate
        }

        public func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }

            var request = try URLRequest(url: components.asURL(), method: .get)

            //TODO improve check. We should store the IPFS hash, if the hash is different, download the new file, otherwise it has not changed
            //IPFS, at least on Infura returns a `304` even though we pass in a timestamp that is older than the creation date for the "IF-Modified-Since" header. So we always download the entire file. This only works decently when we don't have many TokenScript using EIP-5169/`scriptURI()`
            request.allHTTPHeaderFields = httpHeadersWithLastModifiedTimestamp(
                includeLastModifiedTimestampHeader: !url.absoluteString.contains("ipfs"),
                lastModifiedDate: lastModifiedDate)

            return request
        }

        private var httpHeaders: [String: String] {
            guard let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return [:] }
            return [
                "Accept": "application/tokenscript+xml; charset=UTF-8",
                "X-Client-Name": TokenScript.repoClientName,
                "X-Client-Version": appVersion,
                "X-Platform-Name": TokenScript.repoPlatformName,
                "X-Platform-Version": UIDevice.current.systemVersion
            ]
        }

        private static let lastModifiedDateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "E, dd MMM yyyy HH:mm:ss z"
            df.timeZone = TimeZone(secondsFromGMT: 0)
            return df
        }()

        private func httpHeadersWithLastModifiedTimestamp(includeLastModifiedTimestampHeader: Bool, lastModifiedDate: Date?) -> [String: String] {
            var result = httpHeaders
            if includeLastModifiedTimestampHeader, let lastModified = lastModifiedDate {
                result["IF-Modified-Since"] = string(fromLastModifiedDate: lastModified)
                return result
            } else {
                return result
            }
        }

        public func string(fromLastModifiedDate date: Date) -> String {
            return GetXmlFileRequest.lastModifiedDateFormatter.string(from: date)
        }
    }
}
