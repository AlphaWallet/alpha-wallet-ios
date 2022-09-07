// Copyright © 2019 Stormbird PTE. LTD.
import Foundation

struct GetERC721ForTicketsBalance {
    let abi = "[{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"getBalances\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256[]\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}]"
    let name = "getBalances"
}