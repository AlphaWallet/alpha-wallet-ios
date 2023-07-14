//
//  CcipRead.swift
//  web3swift
//
//  Created by Hwee-Boon Yar on Apr/4/22.
//

import Foundation
import PromiseKit

//https://eips.ethereum.org/EIPS/eip-3668#client-lookup-protocol
class CcipRead {
    private let web3: Web3
    private let options: Web3Options
    private let onBlock: String
    private let urls: [String]
    private let sender: EthereumAddress
    private let callbackSelector: String
    private let callData: String
    private let extraData: String

    init?(web3: Web3, options: Web3Options, onBlock: String, fromDataString dataString: String?) {
        if let dataString = dataString, let ccipRead = Self.extractCcipRead(fromDataString: dataString) {
            self.web3 = web3
            self.options = options
            self.onBlock = onBlock
            self.urls = ccipRead.urls
            self.sender = ccipRead.sender
            self.callbackSelector = ccipRead.callbackSelector
            self.callData = ccipRead.callData
            self.extraData = ccipRead.extraData
        } else {
            return nil
        }
    }

    func process() -> Promise<Data> {
        firstly {
            fetchCcipJsonRpcCallbackPayloadHexString(urls: urls)
        }.then { payload in
            CcipRead.ethCall(web3: self.web3, options: self.options, onBlock: self.onBlock, address: self.sender, payload: payload)
        }
    }

    private func fetchCcipJsonRpcCallbackPayloadHexString(urls: [String]) -> Promise<String> {
        struct NoValidResultsFromAllCcipReadGateWayUrlsError: Error {}
        guard !urls.isEmpty else { return Promise(error: NoValidResultsFromAllCcipReadGateWayUrlsError()) }
        var urls = urls
        let url = urls.removeFirst()
        return firstly {
            _fetchCcipJsonRpcCallbackPayloadHexString(url: url)
        }.recover { _ -> Promise<String> in
            return self.fetchCcipJsonRpcCallbackPayloadHexString(urls: urls)
        }
    }

    private func _fetchCcipJsonRpcCallbackPayloadHexString(url rawUrl: String) -> Promise<String> {
        //url eg = "https://offchain-resolver-example.uc.r.appspot.com/{sender}/{data}.json"
        let senderString = sender.address.lowercased().addHexPrefix()
        let dataString = callData.lowercased().addHexPrefix()
        guard let url = URL(string: rawUrl.replacingOccurrences(of: "{sender}", with: senderString).replacingOccurrences(of: "{data}", with: dataString)) else {
            struct InvalidCcipReadGateWayUrl: Error {}
            return Promise(error: InvalidCcipReadGateWayUrl())
        }
        //CCIP Read, GET or POST accordingly
        var request = URLRequest(url: url)
        if rawUrl.contains("{data}") {
            request.httpMethod = "GET"
        } else {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = [
                "sender": senderString,
                "data": dataString
            ]
            do {
                let jsonData = try JSONEncoder().encode(body)
                request.httpBody = jsonData
            } catch {
                struct EncodeCCIPReadGatewayPayloadAsJsonError: Error {}
                return Promise(error: EncodeCCIPReadGatewayPayloadAsJsonError())
            }
        }

        let session = URLSession(configuration: .default)
        return Promise { seal in
            let dataTask = session.dataTask(with: request) { data, _, error in
                if let error = error {
                    seal.reject(error)
                } else if let data = data {
                    if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                        if let dict = json as? [String: Any] {
                            if let result = dict["data"] as? String {
                                let payload = Self.buildCcipJsonRpcCallbackPayloadHexString(callbackSelector: self.callbackSelector, ccipGatewayCallResult: result, extraData: self.extraData)
                                seal.fulfill(payload)
                            }
                        }
                    }
                    struct InvalidCcipReadGatewayFetchResultError: Error {}
                    seal.reject(InvalidCcipReadGatewayFetchResultError())
                }
            }
            dataTask.resume()
        }
    }

    //TODO this might trigger a CCIP Read recursively too, needs a counter to limit infinite recursion
    private static func ethCall(web3: Web3, options: Web3Options, onBlock: String, address: EthereumAddress, payload: String) -> Promise<Data> {
        let eth = Web3.Eth(web3: web3)
        //Empty `Web3Options()` so `gasLimit` is not passed in
        let options = Web3Options()
        let transaction = Transaction(to: address, data: Data(hex: payload), options: options)
        return eth.callPromise(transaction, options: options, onBlock: onBlock)
    }

    //Must not convert `urls` to `[URL]` since URLs can't contain "{sender}" and "{data}"
    private static func extractCcipRead(fromDataString dataString: String?) -> Ccip<EthereumAddress>? {
        guard let dataString = dataString?.addHexPrefix() else { return nil }
        //OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData)
        let hashInterfaceForOffChainLookup = "0x556f1830"
        //count - 2 to exclude "0x"
        if dataString.hasPrefix(hashInterfaceForOffChainLookup), (dataString.count - 2) / 2 % 32 == 4 {
            let ccipRead = _extractCcipRead(dataString: dataString)
            if let sender = EthereumAddress(ccipRead.sender.addHexPrefix(), ignoreChecksum: true) {
                return .init(urls: ccipRead.urls, sender: sender, callbackSelector: ccipRead.callbackSelector, callData: ccipRead.callData, extraData: ccipRead.extraData)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    private struct Ccip<T> {
        let urls: [String]
        let sender: T
        let callbackSelector: String
        let callData: String
        let extraData: String
    }

    private static func _extractCcipRead(dataString: String) -> Ccip<String> {
        let dataString: String = {
            //8 characters for 4 bytes interface hash and +2 for "0x"
            let result = String(dataString.dropFirst(8 + 2))
            //Defensive
            if result.count % 2 == 0 {
                return result
            } else {
                return "0\(result)"
            }
        }()

        var start = 0
        var end = start + 32*2
        let rawSender: String = dataString[start..<end]
        //20 byte address -> 40 in hex
        let sender: String = String(rawSender.dropFirst(rawSender.count - 40))

        start = 32*2
        end = start + 32*2
        let urlsOffsetRaw = dataString[start..<end]
        let urlsOffset = Int(urlsOffsetRaw, radix: 16)!

        start = urlsOffset * 2
        end = start + 32*2
        let urlsLengthRaw = dataString[start..<end]
        let urlsLength = Int(urlsLengthRaw, radix: 16)!

        start = urlsOffset*2 + 32*2
        end = dataString.count
        let urlsData = dataString[start..<end]

        var urls: [String?] = []
        for i in 0..<urlsLength {
            let offsetStart = i*32*2
            let urlRaw = parseBytes(data: urlsData, start: offsetStart)
            let url = String(data: Data(hex: urlRaw), encoding: .utf8)
            urls.append(url)
        }

        let callDataOffsetStart = 64*2
        let callData = parseBytes(data: dataString, start: callDataOffsetStart)

        start = 96*2
        end = start + 4*2
        let callbackSelector = dataString[start..<end]

        let extraData = parseBytes(data: dataString, start: 128*2)

        return .init(urls: urls.compactMap { $0 }, sender: sender, callbackSelector: callbackSelector, callData: callData, extraData: extraData)
    }

    private static func buildCcipJsonRpcCallbackPayloadHexString(callbackSelector: String, ccipGatewayCallResult ccipGatewayCallResultRaw: String, extraData: String) -> String {
        let ccipGatewayCallResult = ccipGatewayCallResultRaw.stripHexPrefix()
        //CCIP callback function has args (bytes,bytes)
        let d: Data = Data(hex: callbackSelector) + encodeBytes(datas: [ccipGatewayCallResult, extraData])
        return d.toHexString()
    }

    private static func parseBytes(data: String, start: Int) -> String {
        let offsetStart = start
        let offSetEnd = offsetStart + 32*2
        let offset = data[offsetStart..<offSetEnd]

        let lengthStartRaw = offset
        let lengthStart = Int(lengthStartRaw, radix: 16)! * 2
        let lengthEnd = lengthStart + 32*2
        let lengthRaw = data[lengthStart..<lengthEnd]

        let length = Int(lengthRaw, radix: 16)! * 2
        let raw = data[lengthEnd..<(lengthEnd+length)]
        return raw
    }

    private static func encodeBytes(datas: [String]) -> Data {
        var result: [Data] = []
        var byteCount = 0
        //Placeholders for pointers to items
        for _ in datas {
            result.append(Data())
            byteCount += 32
        }

        for (i, each) in datas.enumerated() {
            let data = Data(hex: datas[i])
            result[i] = byteCount.numberToPaddedBytes()
            let count = data.count.numberToPaddedBytes()
            result.append(count)
            let paddedData = data.bytesPadded()
            result.append(paddedData)
            byteCount += 32 + paddedData.count
        }
        return Data(result.joined())
    }
}

fileprivate extension Data {
    func leftPaddedDataWithZero(toLength: Int) -> Data {
        let paddingCount = toLength - count
        if paddingCount > 0 {
            return Data(repeating: 0, count: paddingCount) + self
        } else {
            return self
        }
    }

    func rightPaddedDataWithZero(toLength: Int) -> Data {
        let paddingCount = toLength - count
        if paddingCount > 0 {
            return self + Data(repeating: 0, count: paddingCount)
        } else {
            return self
        }
    }

    func bytesPadded() -> Data {
        let paddingCount = 32 - (count % 32)
        if paddingCount > 0 {
            return rightPaddedDataWithZero(toLength: count + paddingCount)
        } else {
            return self
        }
    }
}

fileprivate extension Int {
    func numberToPaddedBytes() -> Data {
        withUnsafeBytes(of: bigEndian) { Data($0) }.leftPaddedDataWithZero(toLength: 32)
    }
}
