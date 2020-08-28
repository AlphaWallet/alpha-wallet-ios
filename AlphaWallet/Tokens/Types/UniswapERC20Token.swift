//
//  UniswapERC20Token.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import Foundation

struct UniswapERC20Token {
    let name: String
    let contract: AlphaWallet.Address
    let decimal: Int
}

extension UniswapERC20Token {
    
    static func isSupport(token: TokenObject) -> Bool {
        switch token.server {
        case .main:
            return availableTokens.contains(where: { $0.contract.sameContract(as: token.contractAddress) })
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_sigma1, .artis_tau1, .custom, .poa, .callisto, .xDai, .classic:
            return false
        }
    }

    private static let availableTokens: [UniswapERC20Token] = [
        .init(name: "ETH", contract: Constants.nullAddress, decimal: 0),
        .init(name: "USDT", contract: AlphaWallet.Address(string: "0xdAC17F958D2ee523a2206206994597C13D831ec7")!, decimal: 6),
        .init(name: "LINK", contract: AlphaWallet.Address(string: "0x514910771AF9Ca656af840dff83E8264EcF986CA")!, decimal: 18),
        .init(name: "BNB", contract: AlphaWallet.Address(string: "0xB8c77482e45F1F44dE1745F52C74426C631bDD52")!, decimal: 18),
        .init(name: "WETH", contract: AlphaWallet.Address(string: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")!, decimal: 18),
        .init(name: "0xBTC", contract: AlphaWallet.Address(string: "0xB6eD7644C69416d67B522e20bC294A9a9B405B31")!, decimal: 8),
        .init(name: "aDAI", contract: AlphaWallet.Address(string: "0xc11d0D5b9e8d7741289e78a52b9D2eFBCEC14478")!, decimal: 18),
        .init(name: "AMN", contract: AlphaWallet.Address(string: "0x737F98AC8cA59f2C68aD658E3C3d8C8963E40a4c")!, decimal: 18),
        .init(name: "AMPL", contract: AlphaWallet.Address(string: "0xD46bA6D942050d489DBd938a2C909A5d5039A161")!, decimal: 9),
        .init(name: "ANJ", contract: AlphaWallet.Address(string: "0xcD62b1C403fa761BAadFC74C525ce2B51780b184")!, decimal: 18),
        .init(name: "ANT", contract: AlphaWallet.Address(string: "0x960b236A07cf122663c4303350609A66A7B288C0")!, decimal: 18),
        .init(name: "AST", contract: AlphaWallet.Address(string: "0x27054b13b1B798B345b591a4d22e6562d47eA75a")!, decimal: 4),
        .init(name: "BAL", contract: AlphaWallet.Address(string: "0xba100000625a3754423978a60c9317c58a424e3D")!, decimal: 18),
        .init(name: "BAND", contract: AlphaWallet.Address(string: "0xBA11D00c5f74255f56a5E366F4F77f5A186d7f55")!, decimal: 18),
        .init(name: "BAT", contract: AlphaWallet.Address(string: "0x0D8775F648430679A709E98d2b0Cb6250d2887EF")!, decimal: 18),
        .init(name: "BLT", contract: AlphaWallet.Address(string: "0x107c4504cd79C5d2696Ea0030a8dD4e92601B82e")!, decimal: 18),
        .init(name: "BNT", contract: AlphaWallet.Address(string: "0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C")!, decimal: 18),
        .init(name: "BTC++", contract: AlphaWallet.Address(string: "0x0327112423F3A68efdF1fcF402F6c5CB9f7C33fd")!, decimal: 18),
        .init(name: "BZRX", contract: AlphaWallet.Address(string: "0x56d811088235F11C8920698a204A5010a788f4b3")!, decimal: 18),
        .init(name: "cDAI", contract: AlphaWallet.Address(string: "0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643")!, decimal: 8),
        .init(name: "CEL", contract: AlphaWallet.Address(string: "0xaaAEBE6Fe48E54f431b0C390CfaF0b017d09D42d")!, decimal: 4),
        .init(name: "CELR", contract: AlphaWallet.Address(string: "0x4F9254C83EB525f9FCf346490bbb3ed28a81C667")!, decimal: 18),
        .init(name: "CHAI", contract: AlphaWallet.Address(string: "0x06AF07097C9Eeb7fD685c692751D5C66dB49c215")!, decimal: 18),
        .init(name: "cUSDC", contract: AlphaWallet.Address(string: "0x39AA39c021dfbaE8faC545936693aC917d5E7563")!, decimal: 8),
        .init(name: "DAI", contract: AlphaWallet.Address(string: "0x6B175474E89094C44Da98b954EedeAC495271d0F")!, decimal: 18),
        .init(name: "DATA", contract: AlphaWallet.Address(string: "0x1B5f21ee98eed48d292e8e2d3Ed82b40a9728A22")!, decimal: 18),
        .init(name: "DGD", contract: AlphaWallet.Address(string: "0xE0B7927c4aF23765Cb51314A0E0521A9645F0E2A")!, decimal: 9),
        .init(name: "DGX", contract: AlphaWallet.Address(string: "0x4f3AfEC4E5a3F2A6a1A411DEF7D7dFe50eE057bF")!, decimal: 9),
        .init(name: "DIP", contract: AlphaWallet.Address(string: "0x97af10D3fc7C70F67711Bf715d8397C6Da79C1Ab")!, decimal: 12),
        .init(name: "DONUT", contract: AlphaWallet.Address(string: "0xC03238A3cb7CA6580f3a89B32AFaC1bcFF87CaE4")!, decimal: 18),
        .init(name: "EBASE", contract: AlphaWallet.Address(string: "0xa689DCEA8f7ad59fb213be4bc624ba5500458dC6")!, decimal: 18),
        .init(name: "ENJ", contract: AlphaWallet.Address(string: "0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c")!, decimal: 18),
        .init(name: "iDAI", contract: AlphaWallet.Address(string: "0x493C57C4763932315A328269E1ADaD09653B9081")!, decimal: 18),
        .init(name: "IOTX", contract: AlphaWallet.Address(string: "0x6fB3e0A217407EFFf7Ca062D46c26E5d60a14d69")!, decimal: 18),
        .init(name: "iSAI", contract: AlphaWallet.Address(string: "0x14094949152EDDBFcd073717200DA82fEd8dC960")!, decimal: 18),
        .init(name: "KEY", contract: AlphaWallet.Address(string: "0x4CC19356f2D37338b9802aa8E8fc58B0373296E7")!, decimal: 18),
        .init(name: "KNC", contract: AlphaWallet.Address(string: "0xdd974D5C2e2928deA5F71b9825b8b646686BD200")!, decimal: 18),
        .init(name: "LEND", contract: AlphaWallet.Address(string: "0x80fB784B7eD66730e8b1DBd9820aFD29931aab03")!, decimal: 18),
        .init(name: "LINK", contract: AlphaWallet.Address(string: "0x514910771AF9Ca656af840dff83E8264EcF986CA")!, decimal: 18),
        .init(name: "MET", contract: AlphaWallet.Address(string: "0xa3d58c4E56fedCae3a7c43A725aeE9A71F0ece4e")!, decimal: 18),
        .init(name: "MGN", contract: AlphaWallet.Address(string: "0x1B941DEd58267a06f4Ab028b446933e578389DAF")!, decimal: 18),
        .init(name: "MKR", contract: AlphaWallet.Address(string: "0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2")!, decimal: 18),
        .init(name: "MLN", contract: AlphaWallet.Address(string: "0xec67005c4E498Ec7f55E092bd1d35cbC47C91892")!, decimal: 18),
        .init(name: "MOD", contract: AlphaWallet.Address(string: "0x957c30aB0426e0C93CD8241E2c60392d08c6aC8e")!, decimal: 0),
        .init(name: "MTA", contract: AlphaWallet.Address(string: "0xa3BeD4E1c75D00fa6f4E5E6922DB7261B5E9AcD2")!, decimal: 18),
        .init(name: "mUSD", contract: AlphaWallet.Address(string: "0xe2f2a5C287993345a840Db3B0845fbC70f5935a5")!, decimal: 18),
        .init(name: "NEXO", contract: AlphaWallet.Address(string: "0xB62132e35a6c13ee1EE0f84dC5d40bad8d815206")!, decimal: 18),
        .init(name: "NMR", contract: AlphaWallet.Address(string: "0x1776e1F26f98b1A5dF9cD347953a26dd3Cb46671")!, decimal: 18),
        .init(name: "RCN", contract: AlphaWallet.Address(string: "0xF970b8E36e23F7fC3FD752EeA86f8Be8D83375A6")!, decimal: 18),
        .init(name: "RDN", contract: AlphaWallet.Address(string: "0x255Aa6DF07540Cb5d3d297f0D0D4D84cb52bc8e6")!, decimal: 18),
        .init(name: "REN", contract: AlphaWallet.Address(string: "0x408e41876cCCDC0F92210600ef50372656052a38")!, decimal: 18),
        .init(name: "renBCH", contract: AlphaWallet.Address(string: "0x459086F2376525BdCebA5bDDA135e4E9d3FeF5bf")!, decimal: 8),
        .init(name: "renBTC", contract: AlphaWallet.Address(string: "0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D")!, decimal: 8),
        .init(name: "renZEC", contract: AlphaWallet.Address(string: "0x1C5db575E2Ff833E46a2E9864C22F4B22E0B37C2")!, decimal: 8),
        .init(name: "REP", contract: AlphaWallet.Address(string: "0xE94327D07Fc17907b4DB788E5aDf2ed424adDff6")!, decimal: 18),
        .init(name: "REPv2", contract: AlphaWallet.Address(string: "0x221657776846890989a759BA2973e427DfF5C9bB")!, decimal: 18),
        .init(name: "RING", contract: AlphaWallet.Address(string: "0x9469D013805bFfB7D3DEBe5E7839237e535ec483")!, decimal: 18),
        .init(name: "SOCKS", contract: AlphaWallet.Address(string: "0xeEAE80e1790c63E390cFB176536D734c28828192")!, decimal: 0),
        .init(name: "SPANK", contract: AlphaWallet.Address(string: "0x42d6622deCe394b54999Fbd73D108123806f6a18")!, decimal: 18),
        .init(name: "SRM", contract: AlphaWallet.Address(string: "0x476c5E26a75bd202a9683ffD34359C0CC15be0fF")!, decimal: 6),
        .init(name: "STAKE", contract: AlphaWallet.Address(string: "0x0Ae055097C6d159879521C384F1D2123D1f195e6")!, decimal: 18),
        .init(name: "STORJ", contract: AlphaWallet.Address(string: "0xB64ef51C888972c908CFacf59B47C1AfBC0Ab8aC")!, decimal: 8),
        .init(name: "sUSD", contract: AlphaWallet.Address(string: "0x57Ab1ec28D129707052df4dF418D58a2D46d5f51")!, decimal: 18),
        .init(name: "sXAU", contract: AlphaWallet.Address(string: "0x261EfCdD24CeA98652B9700800a13DfBca4103fF")!, decimal: 18),
        .init(name: "USDC", contract: AlphaWallet.Address(string: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")!, decimal: 6),
        .init(name: "USDS", contract: AlphaWallet.Address(string: "0x098fEEd90F28493e02f6e745a2767120E7B79A1B")!, decimal: 8),
        .init(name: "USDT", contract: AlphaWallet.Address(string: "0xdAC17F958D2ee523a2206206994597C13D831ec7")!, decimal: 6),
        .init(name: "USDx", contract: AlphaWallet.Address(string: "0xeb269732ab75A6fD61Ea60b06fE994cD32a83549")!, decimal: 18),
        .init(name: "VERI", contract: AlphaWallet.Address(string: "0x8f3470A7388c05eE4e7AF3d01D8C722b0FF52374")!, decimal: 18),
        .init(name: "WBTC", contract: AlphaWallet.Address(string: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599")!, decimal: 8),
        .init(name: "WCK", contract: AlphaWallet.Address(string: "0xb69EfF754380AC7C68ffeE174b881A39dae2f58C")!, decimal: 18),
        .init(name: "XCHF", contract: AlphaWallet.Address(string: "0xB4272071eCAdd69d933AdcD19cA99fe80664fc08")!, decimal: 18),
        .init(name: "XIO", contract: AlphaWallet.Address(string: "0xa45Eaf6d2Ce4d1a67381d5588B865457023c23A0")!, decimal: 18),
        .init(name: "ZRX", contract: AlphaWallet.Address(string: "0xE41d2489571d322189246DaFA5ebDe1F4699F498")!, decimal: 18),
    ]
}
