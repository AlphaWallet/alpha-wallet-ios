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
        case .binance_smart_chain: return R.string.localizable.blockchainBinance()
        case .binance_smart_chain_testnet: return R.string.localizable.blockchainBinanceTest()
        case .heco: return R.string.localizable.blockchainHeco()
        case .heco_testnet: return R.string.localizable.blockchainHecoTest()
        case .main, .callisto, .classic, .goerli: return R.string.localizable.blockchainEthereum()
        case .fantom: return R.string.localizable.blockchainFantom()
        case .fantom_testnet: return R.string.localizable.blockchainFantomTest()
        case .avalanche: return R.string.localizable.blockchainAvalanche()
        case .avalanche_testnet: return R.string.localizable.blockchainAvalancheTest()
        case .polygon: return R.string.localizable.blockchainPolygon()
        case .mumbai_testnet: return R.string.localizable.blockchainMumbai()
        case .optimistic: return R.string.localizable.blockchainOptimistic()
        case .cronosMainnet: return R.string.localizable.blockchainCronosMainnet()
        case .cronosTestnet: return R.string.localizable.blockchainCronosTestnet()
        case .custom(let custom): return custom.chainName
        case .arbitrum: return R.string.localizable.blockchainArbitrum()
        case .palm: return R.string.localizable.blockchainPalm()
        case .palmTestnet: return R.string.localizable.blockchainPalmTestnet()
        case .klaytnCypress: return "Klaytn Cypress"
        case .klaytnBaobabTestnet: return "Klaytn Baobab"
        case .ioTeX: return "IoTeX Mainnet"
        case .ioTeXTestnet: return "IoTeX Testnet"
        case .optimismGoerli: return "Optimism Goerli"
        case .arbitrumGoerli: return "Arbitrum Goerli"
        case .okx: return "OKXChain Mainnet"
        case .sepolia: return "Sepolia"
        }
    }

    var iconImage: UIImage? {
        switch self {
        case .main: return R.image.eth()
        case .xDai: return R.image.xDai()
        case .classic: return R.image.tokenEtc()
        case .callisto: return R.image.tokenCallisto()
        case .binance_smart_chain: return R.image.tokenBnb()
        case .cronosMainnet: return R.image.cronos()
        case .goerli, .binance_smart_chain_testnet, .cronosTestnet, .custom: return nil
        case .heco: return R.image.hthecoMainnet()
        case .heco_testnet: return R.image.hthecoTestnet()
        case .fantom, .fantom_testnet: return R.image.iconsTokensFantom()
        case .avalanche, .avalanche_testnet: return R.image.iconsTokensAvalanche()
        case .polygon, .mumbai_testnet: return R.image.iconsTokensPolygon()
        case .optimistic: return R.image.iconsTokensOptimistic()
        case .arbitrum: return R.image.arbitrum()
        case .palm: return R.image.iconsTokensPalm()
        case .palmTestnet: return nil
        case .klaytnCypress: return R.image.klaytnIcon()
        case .klaytnBaobabTestnet: return R.image.klaytnBaobab()
        case .ioTeX: return R.image.ioTeX()
        case .ioTeXTestnet: return R.image.ioTeXTestnet()
        case .optimismGoerli: return nil
        case .arbitrumGoerli: return nil
        case .okx: return R.image.okc_logo()
        case .sepolia: return R.image.sepolia()
        }
    }

    var blockChainNameColor: UIColor {
        switch self {
        case .main: return Configuration.Color.Semantic.blockChainMain
        case .classic: return Configuration.Color.Semantic.blockChainClassic
        case .callisto: return Configuration.Color.Semantic.blockChainCallisto
        case .goerli: return Configuration.Color.Semantic.blockChainGoerli
        case .xDai: return Configuration.Color.Semantic.blockChainXDai
        case .binance_smart_chain, .binance_smart_chain_testnet: return Configuration.Color.Semantic.blockChainBinanceSmartChain
        case .heco, .heco_testnet: return Configuration.Color.Semantic.blockChainHeco
        case .fantom: return Configuration.Color.Semantic.blockChainFantom
        case .fantom_testnet: return Configuration.Color.Semantic.blockChainFantomTestnet
        case .avalanche: return Configuration.Color.Semantic.blockChainAvalanche
        case .avalanche_testnet: return Configuration.Color.Semantic.blockChainAvalancheTestnet
        case .polygon, .mumbai_testnet: return Configuration.Color.Semantic.blockChainPolygon
        case .optimistic: return Configuration.Color.Semantic.blockChainOptimistic
        case .cronosMainnet: return Configuration.Color.Semantic.blockChainCronosMainnet
        case .cronosTestnet: return Configuration.Color.Semantic.blockChainCronosTestnet
        case .arbitrum: return Configuration.Color.Semantic.blockChainArbitrum
        case .palm: return Configuration.Color.Semantic.blockChainPalm
        case .palmTestnet: return Configuration.Color.Semantic.blockChainPalmTestnet
        case .klaytnCypress: return Configuration.Color.Semantic.blockChainKlaytnCypress
        case .klaytnBaobabTestnet: return Configuration.Color.Semantic.blockChainKlaytnBaobabTestnet
        case .ioTeX: return Configuration.Color.Semantic.blockChainIoTeX
        case .ioTeXTestnet: return Configuration.Color.Semantic.blockChainIoTeXTestnet
        case .optimismGoerli: return Configuration.Color.Semantic.blockChainOptimismGoerli
        case .arbitrumGoerli: return Configuration.Color.Semantic.blockChainArbitrumGoerli
        case .custom: return Configuration.Color.Semantic.blockChainCustom
        case .okx: return Configuration.Color.Semantic.blockChainOkx
        case .sepolia: return Configuration.Color.Semantic.blockChainSepolia
        }
    }

    var staticOverlayIcon: UIImage? {
        switch self {
        case .main: return R.image.iconsNetworkEth()
        case .xDai: return R.image.iconsNetworkXdai()
        case .classic: return nil
        case .callisto: return R.image.iconsNetworkCallisto()
        case .binance_smart_chain: return R.image.iconsNetworkBsc()
        case .goerli, .binance_smart_chain_testnet, .cronosTestnet, .custom: return nil
        case .heco, .heco_testnet: return R.image.iconsNetworkHeco()
        case .cronosMainnet: return R.image.iconsNetworkCronos()
        case .fantom, .fantom_testnet: return R.image.iconsNetworkFantom()
        case .avalanche, .avalanche_testnet: return R.image.iconsNetworkAvalanche()
        case .polygon: return R.image.iconsNetworkPolygon()
        case .mumbai_testnet: return nil
        case .optimistic: return R.image.iconsNetworkOptimism()
        case .arbitrum: return R.image.iconsNetworkArbitrum()
        case .palm, .palmTestnet: return R.image.iconsTokensPalm()
        case .klaytnCypress: return R.image.klaytnIcon()
        case .klaytnBaobabTestnet: return R.image.klaytnIcon()
        case .ioTeX: return R.image.ioTeX()
        case .ioTeXTestnet: return R.image.ioTeXTestnet()
        case .optimismGoerli: return nil
        case .arbitrumGoerli: return nil
        case .okx: return R.image.okc_logo()
        case .sepolia: return R.image.sepolia()
        }
    }
}

extension RPCServer: Comparable {
    public static func < (lhs: RPCServer, rhs: RPCServer) -> Bool {
        switch (lhs.isTestnet, rhs.isTestnet) {
        case (true, false):
            return false
        case (false, true):
            return true
        default:
            return lhs.displayOrderPriority < rhs.displayOrderPriority
        }
    }
}
