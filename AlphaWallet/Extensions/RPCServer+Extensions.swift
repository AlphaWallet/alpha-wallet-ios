//
//  RPCServer+Extensions.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import UIKit
import AlphaWalletFoundation

extension RPCServer {
    var displayName: String {
        if isTestnet {
            return "\(name) (\(R.string.localizable.settingsNetworkTestLabelTitle()))"
        } else {
            return name
        }
    }

    var blockChainName: String {
        switch self {
        case .xDai: return R.string.localizable.blockchainXDAI()
        case .phi: return R.string.localizable.blockchainPhi()
        case .artis_sigma1: return R.string.localizable.blockchainARTISSigma1()
        case .artis_tau1: return R.string.localizable.blockchainARTISTau1()
        case .binance_smart_chain: return R.string.localizable.blockchainBinance()
        case .binance_smart_chain_testnet: return R.string.localizable.blockchainBinanceTest()
        case .heco: return R.string.localizable.blockchainHeco()
        case .heco_testnet: return R.string.localizable.blockchainHecoTest()
        case .main, .rinkeby, .ropsten, .callisto, .classic, .kovan, .sokol, .poa, .goerli: return R.string.localizable.blockchainEthereum()
        case .fantom: return R.string.localizable.blockchainFantom()
        case .fantom_testnet: return R.string.localizable.blockchainFantomTest()
        case .avalanche: return R.string.localizable.blockchainAvalanche()
        case .avalanche_testnet: return R.string.localizable.blockchainAvalancheTest()
        case .polygon: return R.string.localizable.blockchainPolygon()
        case .mumbai_testnet: return R.string.localizable.blockchainMumbai()
        case .optimistic: return R.string.localizable.blockchainOptimistic()
        case .optimisticKovan: return R.string.localizable.blockchainOptimisticKovan()
        case .cronosTestnet: return R.string.localizable.blockchainCronosTestnet()
        case .custom(let custom): return custom.chainName
        case .arbitrum: return R.string.localizable.blockchainArbitrum()
        case .arbitrumRinkeby: return R.string.localizable.blockchainArbitrumRinkeby()
        case .palm: return R.string.localizable.blockchainPalm()
        case .palmTestnet: return R.string.localizable.blockchainPalmTestnet()
        case .klaytnCypress: return "Klaytn Cypress"
        case .klaytnBaobabTestnet: return "Klaytn Baobab"
        case .ioTeX: return "IoTeX Mainnet"
        case .ioTeXTestnet: return "IoTeX Testnet"
        case .candle: return "Candle"
        }
    }

    var iconImage: UIImage? {
        switch self {
        case .main: return R.image.eth()
        case .xDai: return R.image.xDai()
        case .phi: return R.image.phi()
        case .poa: return R.image.tokenPoa()
        case .classic: return R.image.tokenEtc()
        case .callisto: return R.image.tokenCallisto()
        case .artis_sigma1: return R.image.tokenArtis()
        case .binance_smart_chain: return R.image.tokenBnb()
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_tau1, .binance_smart_chain_testnet, .cronosTestnet, .custom: return nil
        case .heco: return R.image.hthecoMainnet()
        case .heco_testnet: return R.image.hthecoTestnet()
        case .fantom, .fantom_testnet: return R.image.iconsTokensFantom()
        case .avalanche, .avalanche_testnet: return R.image.iconsTokensAvalanche()
        case .polygon, .mumbai_testnet: return R.image.iconsTokensPolygon()
        case .optimistic: return R.image.iconsTokensOptimistic()
        case .optimisticKovan: return R.image.iconsTokensOptimisticKovan()
        case .arbitrum: return R.image.arbitrum()
        case .arbitrumRinkeby: return nil
        case .palm: return R.image.iconsTokensPalm()
        case .palmTestnet: return nil
        case .klaytnCypress: return R.image.klaytnIcon()
        case .klaytnBaobabTestnet: return R.image.klaytnBaobab()
        case .ioTeX: return R.image.ioTeX()
        case .ioTeXTestnet: return R.image.ioTeXTestnet()
        case .candle: return R.image.iconsTokensCandle()
        }
    }

    var blockChainNameColor: UIColor {
        switch self {
        case .main: return .init(red: 41, green: 134, blue: 175)
        case .classic: return .init(red: 55, green: 137, blue: 55)
        case .callisto: return .init(red: 88, green: 56, blue: 163)
        case .kovan: return .init(red: 112, green: 87, blue: 141)
        case .ropsten, .custom: return .init(red: 255, green: 74, blue: 141)
        case .rinkeby: return .init(red: 246, green: 195, blue: 67)
        case .poa: return .init(red: 88, green: 56, blue: 163)
        case .sokol: return .init(red: 107, green: 53, blue: 162)
        case .goerli: return .init(red: 187, green: 174, blue: 154)
        case .xDai: return .init(red: 253, green: 176, blue: 61)
        case .phi: return .init(red: 203, green: 126, blue: 31)
        case .artis_sigma1: return .init(red: 83, green: 162, blue: 113)
        case .artis_tau1: return .init(red: 255, green: 117, blue: 153)
        case .binance_smart_chain, .binance_smart_chain_testnet: return .init(red: 255, green: 211, blue: 0)
        case .heco, .heco_testnet: return .init(hex: "1253FC")
        case .fantom: return .red
        case .fantom_testnet: return .red
        case .avalanche: return .red
        case .avalanche_testnet: return .red
        case .polygon, .mumbai_testnet: return .init(red: 130, green: 71, blue: 229)
        case .optimistic: return .red
        case .optimisticKovan: return .red
        case .cronosTestnet: return .red
        case .arbitrum: return .red
        case .arbitrumRinkeby: return .red
        case .palm: return .red
        case .palmTestnet: return .red
        case .klaytnCypress: return .init(hex: "FE3300")
        case .klaytnBaobabTestnet: return .init(hex: "313557")
        case .ioTeX: return .init(hex: "00D4D5")
        case .ioTeXTestnet: return .init(hex: "00D4D5")
        case .candle: return .init(red: 0, green: 46, blue: 171)
        }
    }

    var staticOverlayIcon: UIImage? {
        switch self {
        case .main: return R.image.iconsNetworkEth()
        case .xDai: return R.image.iconsNetworkXdai()
        case .poa: return R.image.iconsNetworkPoa()
        case .classic: return nil
        case .callisto: return R.image.iconsNetworkCallisto()
        case .artis_sigma1: return nil
        case .binance_smart_chain: return R.image.iconsNetworkBsc()
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_tau1, .binance_smart_chain_testnet, .cronosTestnet, .custom: return nil
        case .heco, .heco_testnet: return R.image.iconsNetworkHeco()
        case .fantom, .fantom_testnet: return R.image.iconsNetworkFantom()
        case .avalanche, .avalanche_testnet: return R.image.iconsNetworkAvalanche()
        case .polygon: return R.image.iconsNetworkPolygon()
        case .mumbai_testnet: return nil
        case .optimistic: return R.image.iconsNetworkOptimism()
        case .optimisticKovan: return nil
        case .arbitrum: return R.image.iconsNetworkArbitrum()
        case .arbitrumRinkeby: return nil
        case .palm, .palmTestnet: return R.image.iconsTokensPalm()
        case .klaytnCypress: return R.image.klaytnIcon()
        case .klaytnBaobabTestnet: return R.image.klaytnIcon()
        case .phi: return nil
        case .ioTeX: return R.image.ioTeX()
        case .ioTeXTestnet: return R.image.ioTeXTestnet()
        case .candle: return R.image.iconsNetworkCandle()
        }
    }
}
