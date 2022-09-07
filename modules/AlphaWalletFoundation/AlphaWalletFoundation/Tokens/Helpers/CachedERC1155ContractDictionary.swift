//
//  CachedERC1155ContractDictionary.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 12/4/22.
//

import Foundation

public class CachedERC1155ContractDictionary {
    private let fileUrl: URL
    private var baseDictionary: [AlphaWallet.Address: Bool] = [AlphaWallet.Address: Bool]()
    private var encoder: JSONEncoder

    public init?(fileName: String) {
        do {
            var url: URL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            url.appendPathComponent(fileName)
            self.fileUrl = url
            self.encoder = JSONEncoder()
            if FileManager.default.fileExists(atPath: url.path) {
                readFromFileUrl()
            }
        } catch {
            return nil
        }
    }

    public func isERC1155Contract(for address: AlphaWallet.Address) -> Bool? {
        return baseDictionary[address]
    }

    public func setContract(for address: AlphaWallet.Address, _ result: Bool) {
        baseDictionary[address] = result
        writeToFileUrl()
    }

    public func remove() {
        do {
            try FileManager.default.removeItem(at: fileUrl)
        } catch {
            // Do nothing
            verboseLog("CachedERC1155ContractDictionary::remove Exception: \(error)")
        }
    }

    private func writeToFileUrl() {
        do {
            let data = try encoder.encode(baseDictionary)
            if let jsonString = String(data: data, encoding: .utf8) {
                try jsonString.write(to: fileUrl, atomically: true, encoding: .utf8)
            }
        } catch {
            // Do nothing
            warnLog("[CachedERC1155ContractDictionary] writeToFileUrl error: \(error)")
        }
    }

    private func readFromFileUrl() {
        do {
            let decoder = JSONDecoder()
            let data = try Data(contentsOf: fileUrl)
            let jsonData = try decoder.decode([AlphaWallet.Address: Bool].self, from: data)
            baseDictionary = jsonData
        } catch {
            infoLog("[CachedERC1155ContractDictionary] readFromFileUrl error: \(error)")
            baseDictionary = [AlphaWallet.Address: Bool]()
        }
    }

}
