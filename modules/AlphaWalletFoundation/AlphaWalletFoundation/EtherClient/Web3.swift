//
//  Web3.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 14.09.2022.
//

import Foundation
import web3swift
import BigInt

fileprivate typealias web3swiftWeb3 = web3swift.Web3

public enum Web3 {
    public typealias Web3Error = web3swift.Web3Error
    public typealias EthereumAddress = web3swift.EthereumAddress
    public typealias Eth = web3swift.web3.Eth
    public typealias EventFilterable = web3swift.EventFilterable
    public typealias EventParserResultProtocol = web3swift.EventParserResultProtocol
    public typealias EventFilter = web3swift.EventFilter
    public typealias TransactionReceipt = web3swift.TransactionReceipt
    public typealias Networks = web3swift.Networks
    public typealias RPCNodeHTTPHeaders = web3swift.RPCNodeHTTPHeaders
    public typealias JSONRPCrequestDispatcher = web3swift.JSONRPCrequestDispatcher
    
    public enum Utils {
        static var erc20ABI = web3swiftWeb3.Utils.erc20ABI

        public static func calcualteContractAddress(from: EthereumAddress, nonce: BigUInt) -> EthereumAddress? {
            return web3swiftWeb3.Utils.calcualteContractAddress(from: from, nonce: nonce)
        }

        static public func ecrecover(hash: Data, signature: Data) -> Swift.Result<EthereumAddress, Web3.Web3Error> {
            switch web3swiftWeb3.Utils.hashECRecover(hash: hash, signature: signature) {
            case .some(let value):
                return .success(value)
            case .none:
                return .failure(Web3.Web3Error.walletError)
            }
        }

        /*
             guard let wallet = keystore.currentWallet else { fatalError() }
             guard let message = "Hello AlphaWallet".data(using: .utf8) else { fatalError() }
             guard let signature = try? keystore.signMessage(message, for: wallet.address, prompt: "Sign Message").get() else { fatalError() }

             switch Web3.Utils.ecrecover(message: message, signature: signature) {
             case .success(let address):
                 assert(wallet.address.sameContract(as: address))
             case .failure(let error):
                 print(error)
             }
         */
        public static func ecrecover(message: Data, signature: Data) -> Swift.Result<EthereumAddress, Web3.Web3Error> {
            //need to hash message here because the web3swift implementation adds prefix
            let messageHash = message.sha3(.keccak256)
            let signatureString = signature.hexString.add0x
            //note: web3swift takes the v value as v - 27, so we need to manually convert this
            let vValue = signatureString.drop0x.substring(from: 128)
            let vInt = Int(vValue, radix: 16)! - 27
            let vString = "0" + String(vInt)
            let signature = "0x" + signatureString.drop0x.substring(to: 128) + vString

            switch Web3.Utils.hashECRecover(hash: messageHash, signature: Data(bytes: signature.hexToBytes)) {
            case .some(let value):
                return .success(value)
            case .none:
                return .failure(Web3.Web3Error.walletError)
            }
        }

        public static func privateToPublic(_ privateKey: Data, compressed: Bool = false) -> Data? {
            return web3swiftWeb3.Utils.privateToPublic(privateKey, compressed: compressed)
        }

        public static func publicToAddressData(_ publicKey: Data) -> Data? {
            return web3swiftWeb3.Utils.publicToAddressData(publicKey)
        }

        public static func publicToAddress(_ publicKey: Data) -> EthereumAddress? {
            return web3swiftWeb3.Utils.publicToAddress(publicKey)
        }

        public static func publicToAddressString(_ publicKey: Data) -> String? {
            return web3swiftWeb3.Utils.publicToAddressString(publicKey)
        }

        public static func addressDataToString(_ addressData: Data) -> String {
            return web3swiftWeb3.Utils.addressDataToString(addressData)
        }

        public static func hashPersonalMessage(_ personalMessage: Data) -> Data? {
            return web3swiftWeb3.Utils.hashPersonalMessage(personalMessage)
        }

        static public func personalECRecover(_ personalMessage: String, signature: String) -> EthereumAddress? {
            return web3swiftWeb3.Utils.personalECRecover(personalMessage, signature: signature)
        }

        static public func personalECRecover(_ personalMessage: Data, signature: Data) -> EthereumAddress? {
            return web3swiftWeb3.Utils.personalECRecover(personalMessage, signature: signature)
        }

        static public func hashECRecover(hash: Data, signature: Data) -> EthereumAddress? {
            return web3swiftWeb3.Utils.hashECRecover(hash: hash, signature: signature)
        }

        /// returns Ethereum variant of sha3 (keccak256) of data. Returns nil is data is empty
        static public func keccak256(_ data: Data) -> Data? {
            return web3swiftWeb3.Utils.keccak256(data)
        }

        /// returns Ethereum variant of sha3 (keccak256) of data. Returns nil is data is empty
        static public func sha3(_ data: Data) -> Data? {
            return web3swiftWeb3.Utils.sha3(data)
        }

        /// returns sha256 of data. Returns nil is data is empty
        static public func sha256(_ data: Data) -> Data? {
            return web3swiftWeb3.Utils.sha256(data)
        }
    }
}
