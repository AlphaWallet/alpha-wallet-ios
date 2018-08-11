import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore
import JavaScriptKit
import web3swift

class GetERC875BalanceCoordinator {

    private let web3: Web3Swift
    init(
        web3: Web3Swift
    ) {
        self.web3 = web3
    }
    static var web3Again: web3swift.web3 = {
        //kkk Config()
        let config = Config()
        let nodeURL = config.rpcURL
        //kkk name: web3Again
        //kkk forced unwrap
        let web3 = web3swift.web3(provider: Web3HttpProvider(nodeURL, network: config.server.web3Network)!)
        return web3
    }()

    func getERC875TokenBalance(
        for address: Address,
        contract: Address,
        completion: @escaping (Result<[String], AnyError>) -> Void
    ) {
        let startWeb3SwiftPodTime = Date()
        //kkk forced unwrap
        let contractAddress = EthereumAddress(contract.eip55String)!
        /*
        //kkk Config()
        let config = Config()
        let nodeURL = config.rpcURL
        //kkk name: web3Again
        //kkk forced unwrap
        let web3Again = web3swift.web3(provider: Web3HttpProvider(nodeURL, network: config.server.web3Network)!)
        */
        let web3Again = GetERC875BalanceCoordinator.web3Again
        //kkk name: contract1
        let contract1 = web3swift.web3.web3contract(web3: web3Again, abiString: "[\(GetERC875BalanceEncode.abi)]", at: contractAddress, options: web3Again.options)!

//        DispatchQueue.global().async {
            guard let bkxBalanceResult = contract1.method("balanceOf", parameters: [address.eip55String] as [AnyObject], options: nil)?.call(options: nil) else {
                //kkk completion with .error
                return
            }
//            DispatchQueue.main.sync {
                //kkk change to promise, somehow?
                if case .success(let bkxBalance) = bkxBalanceResult {
                    let balances = self.adapt2(bkxBalance["0"])
//                    NSLog("xxx here 1: \(balances)")
                    NSLog("xxx time taken with web3swift pod to fetch ERC875 balance: \(Date().timeIntervalSince(startWeb3SwiftPodTime) * 1000)")
                    completion(.success(balances))
                } else {
//                    NSLog("xxx here 2")
                    //kkk completion with .error
                }
//            }
//        }

        let startManualEncodeDecodeTime = Date()
        let request = GetERC875BalanceEncode(address: address)
        web3.request(request: request) { result in
            switch result {
            case .success(let res):
                let request2 = EtherServiceRequest(
                    batch: BatchFactory().create(CallRequest(to: contract.description, data: res))
                )
                Session.send(request2) { [weak self] result2 in
                    switch result2 {
                    case .success(let balance):
                        let request = GetERC875BalanceDecode(data: balance)
                        self?.web3.request(request: request) { result in
                            switch result {
                            case .success(let res):
                                let values: [String] = (self?.adapt(res))!
                                NSLog("result \(values)")
                                NSLog("xxx time taken with manual encode/decode with fetch ERC875 balance : \(Date().timeIntervalSince(startManualEncodeDecodeTime) * 1000)")
                                completion(.success(values))
                            case .failure(let error):
                                let err = error.error
                                if err is JSErrorDomain { // TODO:
                                    switch err {
                                    case JSErrorDomain.invalidReturnType(let value):
                                        let values: [String] = (self?.adapt(value))!
                                        NSLog("result error \(values)")
                                        NSLog("xxx time taken with manual encode/decode with fetch ERC875 balance : \(Date().timeIntervalSince(startManualEncodeDecodeTime) * 1000)")
                                        completion(.success(values))
                                    default:
                                         completion(.failure(AnyError(error)))
                                    }
                                } else {
                                    NSLog("getPrice3 error \(error)")
                                    completion(.failure(AnyError(error)))
                                }
                            }
                        }
                    case .failure(let error):
                        NSLog("getPrice2 error \(error)")
                        completion(.failure(AnyError(error)))
                    }
                }
            case .failure(let error):
                NSLog("getPrice error \(error)")
                completion(.failure(AnyError(error)))
            }
        }
    }
}

extension GetERC875BalanceCoordinator {
    private func adapt(_ values: Any) -> [String] {
        if let array = values as? [Any] {
            return array.map { String(describing: $0) }
        }
        return []
    }

    private func adapt2(_ values: Any) -> [String] {
        if let array = values as? [Data] {
            return array.map { each in
                //kkk can we use data.toHexString().addHexPrefix() ?
                let value = each.map { String(format: "%02hhx", $0)}.joined()
                return "0x\(value)"
            }
        }
        return []
    }
}
