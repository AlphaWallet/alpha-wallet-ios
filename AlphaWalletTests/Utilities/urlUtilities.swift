//
//  urlUtilities.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 14/4/22.
//

import Foundation

func cacheUrlFor(fileName: String) throws -> URL {
    var url: URL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    url.appendPathComponent(fileName)
    return url
}

func documentUrlFor(fileName: String) throws -> URL {
    var url: URL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    url.appendPathComponent(fileName)
    return url
}
