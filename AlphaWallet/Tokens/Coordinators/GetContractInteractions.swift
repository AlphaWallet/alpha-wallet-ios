//
// Created by James Sangalli on 6/6/18.
//

import Foundation
import Alamofire
import SwiftyJSON

class GetContractInteractions {

    private let web3: Web3Swift
    private let mainnetEtherscanAPI = "https://api.etherscan.io/api?module=account&action=txlist&address="
    private let ropstenEtherscanAPI = "https://ropsten.etherscan.io/api?module=account&action=txlist&address="
    private let rinkebyEtherscanAPI = "https://rinkeby.etherscan.io/api?module=account&action=txlist&address="


    init(web3: Web3Swift) {
        self.web3 = web3
    }

    //This function only gets a list of contracts you have transacted with
    //if you have not transacted with the contract then it will not show up
    //there is currently no efficient way to get all your tokens but it might be for the best
    //as people spam via sending tokens
    func getContractList(address: String, chainId: Int, completion: @escaping ([String]) -> Void) {
        let etherscanURL = getEtherscanURL(chainId: chainId) + address
        var contracts: [String] = [String]()
        Alamofire.request(URL(string: etherscanURL)!).validate().responseJSON { response in
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

    func getEtherscanURL(chainId: Int) -> String {
        switch chainId {
            case 1:
                return mainnetEtherscanAPI
            case 3:
                return ropstenEtherscanAPI
            case 4:
                return rinkebyEtherscanAPI
            default:
                return mainnetEtherscanAPI
        }
    }

}