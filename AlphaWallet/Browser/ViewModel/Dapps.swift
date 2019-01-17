// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

enum Dapps {
    static let masterList = [
        Dapp(name: "State of the ÐApps", description: "Directory of Decentralized Applications", url: "https://www.stateofthedapps.com/", cat: "Directory"),
        Dapp(name: "Axie Infinity", description: "Collect and raise fantasy creatures", url: "https://axieinfinity.com/", cat: "Game"),
        Dapp(name: "ChickenHunt", description: "character-growing IDLE game", url: "https://chickenhunt.io/", cat: "Game"),
        Dapp(name: "CryptoCare", description: "Social Impact Collectibles", url: "https://cryptocare.tech/adopt/cryptocare", cat: "Game"),
        Dapp(name: "Dice2win", description: "Simple and fair dice game", url: "https://dice2.win/", cat: "Game"),
        Dapp(name: "Dragonereum", description: "Own and trade dragons, fight with other players", url: "https://dapp.dragonereum.io/", cat: "Game"),
        Dapp(name: "HyperDragons", description: "Large scale strategy battle game", url: "https://hyperdragons.alfakingdom.com/", cat: "Game"),
        Dapp(name: "Last Trip", description: "A RPG game", url: "http://lasttrip.matrixdapp.com/", cat: "Game"),
        Dapp(name: "LORDLESS", description: "Be a bounty hunter in my tavern", url: "https://game.lordless.io/home", cat: "Game"),
        Dapp(name: "MLB Crypto Baseball", description: "Baseball collectible game", url: "https://mlbcryptobaseball.com", cat: "Game"),
        Dapp(name: "Radi.Cards", description: "Creative, unique art pieces from from all around the interwebs.", url: "https://radi.cards/cardshop", cat: "Game"),
        Dapp(name: "Augur", description: "Decentralized prediction market", url: "https://www.augur.net/ipfs-redirect.html", cat: "Marketplace"),
        Dapp(name: "Name Bazaar", description: "A peer-to-peer marketplace for the exchange of names registered via the ENS", url: "https://namebazaar.io/", cat: "Marketplace"),
        Dapp(name: "OpenSea", description: "Peer-to-peer marketplace for scarce digital goods", url: "https://opensea.io", cat: "Marketplace"),
        Dapp(name: "SuperRare", description: "Collect art or submit your art as a creator", url: "https://superrare.co/", cat: "Marketplace"),
        Dapp(name: "Veil", description: "A peer-to-peer trading platform for prediction markets and derivatives", url: "https://app.veil.co/", cat: "Marketplace"),
        Dapp(name: "Gravity", description: "Create your gravatar.", url: "https://gravity.cool/", cat: "Property"),
        Dapp(name: "Mokens", description: "Create your own collectibles", url: "https://mokens.io/", cat: "Property"),
        Dapp(name: "TENZ-ID", description: "TENZ-ID is a Decentralized Blockchain naming system", url: "https://tenzorum.org/tenz_id/", cat: "Property"),
        Dapp(name: "MonitorChain", description: "Real-time surveillance", url: "https://secure.monitorchain.com/", cat: "Security"),
        Dapp(name: "Cent", description: "Earn cryptocurrency sharing your wisdom and creativity.", url: "https://beta.cent.co/", cat: "Social Media"),
        Dapp(name: "Indorse", description: "Professional Network", url: "https://indorse.io/", cat: "Social Media"),
        Dapp(name: "Peepeth", description: "Unstoppable microblogging", url: "https://peepeth.com/welcome", cat: "Social Media"),
        Dapp(name: "Amberdata", description: "Your platform for blockchain health and intelligence.", url: "https://amberdata.io/", cat: "Tool"),
        Dapp(name: "Gitcoin", description: "Incentivize or monetize work.", url: "https://gitcoin.co/", cat: "Tool"),
        Dapp(name: "Is that my Contract?", description: "Find and use all your smart contracts", url: "https://alphawallet.github.io/dude-where-is-my-dapp/", cat: "Tool"),
        Dapp(name: "Kickback", description: "Event management platform", url: "https://kickback.events/", cat: "Tool"),
        Dapp(name: "NFT Token Factory", description: "Ccreate an ERC875 NFT contract at the click of a button", url: "https://tf.alphawallet.com/", cat: "Tool"),
        Dapp(name: "SmartDrops", description: "A platform that lets people earn crypto by joining new token projects.", url: "https://www.smartdrops.io/", cat: "Tool"),
        Dapp(name: "xDai Bridge", description: "xDai/Ethereum bridge for self transfers of Dai to xDai", url: "https://dai-bridge.poa.network/", cat: "Tool"),
        Dapp(name: "0x Instant", description: "A free and flexible way to offer simple crypto purchasing", url: "http://0x-instant-staging.s3-website-us-east-1.amazonaws.com/", cat: "Exchange"),
        Dapp(name: "Bancor", description: "Built-in price discovery and a liquidity mechanism for tokens", url: "https://www.bancor.network", cat: "Exchange"),
        Dapp(name: "KyberSwap", description: "Instant and Secure Token to Token Swaps", url: "https://kyber.network/swap/eth_knc", cat: "Exchange"),
        Dapp(name: "localethereum", description: "Peer-to-peer marketplace allowing to trade eth to fiat", url: "https://localethereum.com/", cat: "Exchange"),
        Dapp(name: "Totle", description: "Aggregating the liquidity of the top decentralized exchanges", url: "https://app.totle.com/", cat: "Exchange"),
        Dapp(name: "Uniswap", description: "Protocol for automated token exchange", url: "https://uniswap.exchange/swap", cat: "Exchange"),
        Dapp(name: "Compound", description: "Algorithmic money markets", url: "https://app.compound.finance/", cat: "Finance"),
        Dapp(name: "expo", description: "Short/Leverag ETH", url: "https://www.expotrading.com/trade", cat: "Finance"),
        Dapp(name: "MakerDAO CDP Portal", description: "Where you can interact with the Dai Credit System", url: "https://cdp.makerdao.com/", cat: "Finance"),
        Dapp(name: "AirSwap", description: "Peer-to-Peer trading on Ethereum", url: "https://airswap.io", cat: "Exchange"),
        Dapp(name: "Chibi Fighters", description: "Chibi Fighters are fierce little warriors that know no mercy", url: "https://chibifighters.io", cat: "Games"),
        Dapp(name: "CryptoKitties", description: "Collect and breed digital cats!", url: "https://cryptokitties.co", cat: "Games"),
    ]

    struct Category {
        let name: String
        var dapps: [Dapp]
    }

    static let categorisedDapps: [Category] = {
        var results = [String: Category]()
        for each in masterList {
            let catName = each.cat
            if var cat = results[catName] {
                var dapps = cat.dapps
                dapps.append(each)
                cat.dapps = dapps
                results[catName] = cat
            } else {
                var cat = Category(name: catName, dapps: [each])
                results[catName] = cat
            }
        }
        return results.values.sorted { $0.name < $1.name }
    }()
}
