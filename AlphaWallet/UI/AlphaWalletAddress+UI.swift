// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

extension AlphaWallet.Address {
    var tokenImage: UIImage? {
        switch eip55String {
        case "0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643":
            return R.image.tokenCdai()
        case "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359":
            return R.image.tokenDai()
        case "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2":
            return R.image.tokenWeth()
        case "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599":
            return R.image.tokenWbtc()
        case "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48":
            return R.image.tokenUsdc()
        case "0x493C57C4763932315A328269E1ADaD09653B9081":
            return R.image.tokenIdai()
        default:
            return nil
        }
    }
}
