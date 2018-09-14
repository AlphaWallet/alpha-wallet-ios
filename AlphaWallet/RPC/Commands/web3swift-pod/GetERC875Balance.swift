// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

struct GetERC875Balance {
    let abi = "{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"balanceOf\",\"outputs\":[{\"name\":\"\",\"type\":\"bytes32[]\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}"
    let name = "balanceOf"
}
