//
//  FileTokenEntriesProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.09.2022.
//

import Foundation
import Combine
import CombineExt
import AlphaWalletCore

fileprivate let threadSafeForTokenEntries = ThreadSafe(label: "org.alphawallet.swift.tokenEntries")
public final class FileTokenEntriesProvider: TokenEntriesProvider {
    private let absoluteFilename: String
    private var cachedTokenEntries: [TokenEntry] = []

    public init(absoluteFilename path: String? = nil) {
        if let path = path {
            absoluteFilename = path
        } else {
            absoluteFilename = Self.defaultFilePath()
        }

    }

    //Public to make available for testing
    //Force unwraps protected by unit test — try removing to replace with dummy to see test fails
    private static func defaultFilePath() -> String {
        let resourceBundleUrl = Bundle(for: FileTokenEntriesProvider.self).url(forResource: String(reflecting: FileTokenEntriesProvider.self).components(separatedBy: ".").first!, withExtension: "bundle")!
        let resourceBundle = Bundle(url: resourceBundleUrl)!
        let url = resourceBundle.url(forResource: "tokens_2", withExtension: "json")!
        return url.path
    }

    public func tokenEntries() -> AnyPublisher<[TokenEntry], PromiseError> {
        if cachedTokenEntries.isEmpty {
            var publisher: AnyPublisher<[TokenEntry], PromiseError>!
            threadSafeForTokenEntries.performSync {
                do {
                    guard let jsonData = try String(contentsOfFile: absoluteFilename).data(using: .utf8) else { throw TokenJsonReader.error.fileIsNotUtf8 }
                    do {
                        cachedTokenEntries = try JSONDecoder().decode([TokenEntry].self, from: jsonData)
                        publisher = .just(cachedTokenEntries)
                    } catch DecodingError.dataCorrupted {
                        throw TokenJsonReader.error.fileCannotBeDecoded
                    } catch {
                        throw TokenJsonReader.error.unknown(error)
                    }
                } catch {
                    publisher = .fail(.some(error: error))
                }
            }

            return publisher
        } else {
            return .just(cachedTokenEntries)
        }
    }
}
