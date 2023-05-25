//
//  Erc20TransferNotification.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 24.04.2023.
//

import Foundation
import SwiftyJSON
import AlphaWalletFoundation

public struct Erc20TransferNotification {
    public let body: Body
    public let title: Title

    public struct Body {
        public let to: AlphaWallet.Address
        public let from: AlphaWallet.Address
        public let server: RPCServer
        public let event: String
        public let contract: AlphaWallet.Address
        public let blockNumber: String
        public let contractType: String
    }

    public struct Title {
        public let contract: AlphaWallet.Address
        public let wallet: AlphaWallet.Address
        public let server: RPCServer
        public let event: String
    }
}

extension Erc20TransferNotification.Title {
    init?(json: JSON) {
        guard let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: json["contract"].stringValue),
              let wallet = AlphaWallet.Address(uncheckedAgainstNullAddress: json["wallet"].stringValue),
              let server = Int(chainId0xString: json["chainId"].stringValue).flatMap({ RPCServer(chainID: $0) }),
              let event = json["event"].string else {

            return nil
        }

        self.contract = contract
        self.wallet = wallet
        self.server = server
        self.event = event
    }
}

extension Erc20TransferNotification.Body {

    init?(json: JSON) {
        guard let from = AlphaWallet.Address(uncheckedAgainstNullAddress: json["from"].stringValue),
              let to = AlphaWallet.Address(uncheckedAgainstNullAddress: json["to"].stringValue),
              let contract = AlphaWallet.Address(uncheckedAgainstNullAddress: json["contract"].stringValue),
              let blockNumber = json["blockNumber"].string,
              let server = Int(chainId0xString: json["chainId"].stringValue).flatMap({ RPCServer(chainID: $0) }),
              let event = json["event"].string,
              let contractType = json["contractType"].string else {

            return nil
        }

        self.to = to
        self.from = from
        self.server = server
        self.event = event
        self.contract = contract
        self.blockNumber = blockNumber
        self.contractType = contractType
    }
}

extension Erc20TransferNotification {

    init?(json: JSON) {
        guard let title = Title(json: json["title"]), let body = Body(json: json["body"]) else {
            return nil
        }
        self.title = title
        self.body = body
    }
}
