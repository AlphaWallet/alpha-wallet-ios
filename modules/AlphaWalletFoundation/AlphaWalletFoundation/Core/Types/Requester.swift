//
//  Requester.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.06.2022.
//

import Foundation

public struct Requester {
    public let shortName: String
    public let name: String
    public let server: RPCServer?
    public let url: URL?
    public let iconUrl: URL?

    public init(shortName: String, name: String, server: RPCServer?, url: URL?, iconUrl: URL?) {
        self.shortName = shortName
        self.name = name
        self.server = server
        self.url = url
        self.iconUrl = iconUrl
    }
}
