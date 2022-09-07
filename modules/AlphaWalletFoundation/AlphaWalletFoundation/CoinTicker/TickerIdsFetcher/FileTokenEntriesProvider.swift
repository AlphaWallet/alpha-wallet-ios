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
    private let fileName: String
    private var cachedTokenEntries: [TokenEntry] = []

    public init(fileName: String) {
        self.fileName = fileName
    }

    public func tokenEntries() -> AnyPublisher<[TokenEntry], PromiseError> {
        if cachedTokenEntries.isEmpty {
            var publisher: AnyPublisher<[TokenEntry], PromiseError>!
            threadSafeForTokenEntries.performSync {
                do {
                    guard let bundlePath = Bundle.main.path(forResource: fileName, ofType: "json") else { throw TokenJsonReader.error.fileDoesNotExist }
                    guard let jsonData = try String(contentsOfFile: bundlePath).data(using: .utf8) else { throw TokenJsonReader.error.fileIsNotUtf8 }
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
