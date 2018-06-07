//
// Created by James Sangalli on 6/6/18.
//

import Foundation
import Alamofire
import SwiftyJSON

class GetContractInteractions {

    private let web3: Web3Swift

    init(web3: Web3Swift) {
        self.web3 = web3
    }

    //This function only gets a list of contracts you have transacted with
    //if you have not transacted with the contract then it will not show up
    //there is currently no efficient way to get all your tokens but it might be for the best
    //as people spam via sending tokens
    func getContractList(address: String, chainId: Int, completion: @escaping ([String]) -> Void) {
        let etherscanURL = RPCServer(chainID: chainId).etherscanAPIURLForTransactionList(for: address)
        var contracts: [String] = [String]()
        Alamofire.request(etherscanURL).validate().responseJSON { response in
            switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    for i in 0...json["result"].count - 1 {
                        let contractAddress = json["result"][i]["contractAddress"]
                        if contractAddress != "" {
                            contracts.append(contractAddress.description)
                        }
                    }
                case .failure(let error):
                    print(error)
            }
            completion(contracts)
        }
    }
}