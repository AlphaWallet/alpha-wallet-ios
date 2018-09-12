//
// Created by James Sangalli on 14/7/18.
//

import Foundation

struct GetERC721Balance {
    let abi = "{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"tokensOfOwner\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256[]\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"
    let name = "tokensOfOwner"
}
