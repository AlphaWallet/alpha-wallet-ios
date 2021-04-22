//
//  KaleidoService.swift
//  AlphaWallet
//

import Foundation
import PromiseKit
import Result
import web3swift
import BigInt
import Alamofire
import SwiftyJSON

struct KaleidoTransaction: Codable {
    let index: Int
    let hash, blockHash: String
    let blockNumber: Int
    let timestamp: String
    let status: String
    let welcomePrivate: Bool
    let from: String
    let to: String?
    let events: [KEvent]?
    let isERC20: Bool?

    enum CodingKeys: String, CodingKey {
        case index, hash, blockHash, blockNumber, timestamp, status
        case welcomePrivate = "private"
        case from, to, events, isERC20
    }
}
struct KEvent: Codable {
    let eventSignature, from, to, value: String
}

class KaleidoService {
    private struct Constants {
        //authToken - Kaleido console -> app credentials
        static let authToken = "Bearer u0q4v4vo3f-8Wk8P4tD9qZ25ZVhpYgZj4EUBIk60ulMm7tc+tHR3n0="
        //Kaleido creds
        static let consortiaID = "e0hr1zgg19"
        static let environmentID = "e0iipo4q1k"
        
        //App Cred information - password
        static let appPass = "09eyOAQ43QT_p0pHLbk4mJNyNMMOmJH5BNlfBQ4MCf8"
        
        //struct - "AppID":"password"@"node RPC endpoint"
        //https://console-eu.kaleido.io/api/v1/consortia/{consortia_id}/environments/{environment_id}/nodes/{node_id}/status
        //https://console-eu.kaleido.io/api/v1/consortia/e0hr1zgg19/environments/e0iipo4q1k/appcreds
        static let rpcUrl = "https://e0kbx19fxl:5RFakz1lpNQnqJV6JtG2o-Z4oBBFAwt3cTHIa0T4Z94@e0iipo4q1k-e0wrfvrsl9-rpc.de0-aws.kaleido.io/"
       
        //"NODE ID HASH" - was retrieved from node specs in console (Public Ethereum Tethering)
        //Can be used to import wallet using "Private key" option
        //API request - https://console-eu.kaleido.io/api/v1/consortia/{consortia_id}/environments/{environment_id}/nodes/{node_id}
        static let nodePrivateKey = "0xca33b33e7d30c92a367660baa66290b88c2670e4b0d47336217166bbf34acd40"
        
        // can be retrieved using API call to Kaleido
        // API request - https://console-eu.kaleido.io/api/v1/consortia/{consortiaID}/environments
        static let chainId: UInt64 = 1494873608
    }
   
    // MARK: Send ETH using web3swift
    static func send(to: AlphaWallet.Address) -> String {
        guard let rpcUrl = URL(string: Constants.rpcUrl),
              let plainKS = PlainKeystore(privateKey: Constants.nodePrivateKey) else {
            return "error"
        }
        let keystoreManager = KeystoreManager([plainKS])
        guard let webProvider = Web3HttpProvider(rpcUrl, keystoreManager: keystoreManager) else {
            return "no webProvider"
        }
        let receiver = EthereumAddress(address: to)
        guard let from = plainKS.addresses?.first else {
            return "no from"
        }
        let web3 = web3swift.web3(provider: webProvider)
        let eth = web3swift.web3.Eth(provider: web3.provider, web3: web3)
        let browFunc = web3swift.web3.BrowserFunctions(provider: web3.provider, web3: web3)
        
        let value: String = "0.0" // In Eth. - sending 0 as Test Kaleido account is not funded
        let amount = Web3.Utils.parseToBigUInt(value, units: .eth)
        var options = web3swift.Web3Options.defaultOptions()
        options.from = from
        options.to = receiver
        options.value = amount
        let nonceResult = eth.getTransactionCount(address: from, onBlock: "pending")
        if case .failure(_) = nonceResult {
            return "no nonce"
        }
        
        var trx = EthereumTransaction(to: receiver, data: Data(), options: options)
        trx.UNSAFE_setChainID(BigUInt(integerLiteral: Constants.chainId))
        var prepared = browFunc.prepareTxForApproval(trx, options: options)
        prepared.transaction?.nonce = nonceResult.value!
        guard let transaction = prepared.transaction, let preparedOptions = prepared.options else {
            return "cant prepare"
        }

        if let signData = browFunc.signTransaction(transaction, options: preparedOptions, password: Constants.appPass) {
            trx.data = signData.toHexData
            if let sendData = browFunc.sendTransaction(transaction, options: preparedOptions, password: Constants.appPass),
               let hash = sendData["txhash"] as? String {
                return hash
            }
        }
        return "error"
    }
    
    // MARK: get all acount transaction (both tokens and eth.)
    static func getTransactions(completion: @escaping ([KaleidoTransaction]) -> Void) {
        guard let url = URL(string: "https://console-eu.kaleido.io/api/v1/ledger/\(Constants.consortiaID)/\(Constants.environmentID)/transactions") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Constants.authToken,
                         forHTTPHeaderField: "Authorization")
        Alamofire.request(request).responseJSON { (data) in
            switch data.result {
            case .success(let dataResponse):
                do {
                    let json  = JSON(dataResponse)
                    let decoder = JSONDecoder()
                    let model = try decoder.decode([KaleidoTransaction].self, from: json.rawData())
                    completion(model)
                } catch let parsingError {
                    print("Error", parsingError.localizedDescription)
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }

    // MARK: Fund an account from the environment's faucet. Can transfer ETH or tokens owned by the faucet account. Here "token" transfering implemented.
    static func fundAccount(with tokenAddress: String, to: String, amount: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "https://console-eu.kaleido.io/api/v1/consortia/\(Constants.consortiaID)/environments/\(Constants.environmentID)/eth/fundaccount") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Constants.authToken,
                         forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-type")
        let json: [String: Any] = ["type": "token",
                                   "account": "\(to)",
                                   "amount": "\(amount)",
                                   "unit": "ether",
                                   "tokenAddress": "\(tokenAddress)"]

        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData

        Alamofire.request(request).responseJSON { (data) in
            switch data.result {
            case .success(let dataResponse):
                let json  = JSON(dataResponse)
                let hash = json.dictionary?["transactionHash"]
                completion(hash?.stringValue ?? "no hash received")
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}

