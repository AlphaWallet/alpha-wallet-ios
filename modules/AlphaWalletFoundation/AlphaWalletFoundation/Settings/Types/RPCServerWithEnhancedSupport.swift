// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

//The existence of this type is to dramatically reduce the number of files (20 files as of 20220922) and changes needed to add a chain/RPCServer
//Adding a new case here means more maintenance work when that type is updated.
public enum RPCServerWithEnhancedSupport {
    case main
    case xDai
    case polygon
    case binance_smart_chain
    case heco
    case rinkeby
    case arbitrum
    case klaytnCypress
    case klaytnBaobabTestnet
}
