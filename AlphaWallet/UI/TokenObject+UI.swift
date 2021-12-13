// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import PromiseKit

typealias TokenImage = (image: WebImageViewImage, symbol: String, isFinal: Bool)
typealias Image = UIImage

private func programmaticallyGeneratedIconImage(for contractAddress: AlphaWallet.Address, server: RPCServer) -> UIImage {
    let backgroundColor = symbolBackgroundColor(for: contractAddress, server: server)
    return UIView.tokenSymbolBackgroundImage(backgroundColor: backgroundColor)
}

private func symbolBackgroundColor(for contractAddress: AlphaWallet.Address, server: RPCServer) -> UIColor {
    if contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
        return server.blockChainNameColor
    } else {
        let colors = [R.color.radical()!, R.color.cerulean()!, R.color.emerald()!, R.color.indigo()!, R.color.azure()!, R.color.pumpkin()!]
        let index: Int
        //We just need a random number from the contract. The LSBs are more random than the MSBs
        if let i = Int(contractAddress.eip55String.substring(from: 37), radix: 16) {
            index = i % colors.count
        } else {
            index = 0
        }
        return colors[index]
    }
}

extension RPCServer {
    var walletConnectIconImage: Subscribable<Image> {
        return RPCServerImageFetcher.instance.image(server: self)
    }

    fileprivate var _walletConnectIconImage: UIImage? {
        switch self {
        case .main:
            return R.image.iconsNetworkEth()
        case .xDai:
            return R.image.iconsNetworkXdai()
        case .poa:
            return R.image.iconsNetworkPoa()
        case .classic:
            return nil
        case .callisto:
            return R.image.iconsNetworkCallisto()
        case .artis_sigma1:
            return nil
        case .binance_smart_chain:
            return R.image.iconsNetworkBsc()
        case .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_tau1, .binance_smart_chain_testnet, .cronosTestnet, .custom:
            return nil
        case .heco, .heco_testnet:
            return R.image.iconsNetworkHeco()
        case .fantom, .fantom_testnet:
            return R.image.iconsNetworkFantom()
        case .avalanche, .avalanche_testnet:
            return R.image.iconsNetworkAvalanche()
        case .polygon:
            return R.image.iconsNetworkPolygon()
        case .mumbai_testnet:
            return nil
        case .optimistic:
            return R.image.iconsNetworkOptimism()
        case .optimisticKovan:
            return nil
        case .arbitrum:
            return R.image.iconsNetworkArbitrum()
        case .palm, .palmTestnet:
            return R.image.iconsTokensPalm()
        }
    }
}

class RPCServerImageFetcher {
    static var instance = RPCServerImageFetcher()

    private static var subscribables: ThreadSafeDictionary<Int, Subscribable<Image>> = .init()

    private static func programmaticallyGenerateIcon(for server: RPCServer) -> Image {
        return UIView.tokenSymbolBackgroundImage(backgroundColor: server.blockChainNameColor)
    }

    func image(server: RPCServer) -> Subscribable<Image> {
        if let sub = Self.subscribables[server.chainID] {
            return sub
        } else {
            let sub = Subscribable<Image>(nil)
            Self.subscribables[server.chainID] = sub

            if let value = server._walletConnectIconImage {
                sub.value = value
            } else {
                sub.value = Self.programmaticallyGenerateIcon(for: server)
            }

            return sub
        }
    }
}

extension TokenObject {
    fileprivate static let numberOfCharactersOfSymbolToShowInIcon = 4

    var icon: Subscribable<TokenImage> {
        switch type {
        case .nativeCryptocurrency:
            if let img = server.iconImage {
                return .init((image: .image(img), symbol: "", isFinal: true))
            }
        case .erc20, .erc875, .erc721, .erc721ForTickets, .erc1155:
            if let img = contractAddress.tokenImage {
                return .init((image: .image(img), symbol: "", isFinal: true))
            }
        }
        return TokenImageFetcher.instance.image(forToken: self)
    }
}

class TokenImageFetcher {
    enum ImageAvailabilityError: LocalizedError {
        case notAvailable
    }

    static var instance = TokenImageFetcher()

    private static var subscribables: ThreadSafeDictionary<String, Subscribable<TokenImage>> = .init()
    private let queue: DispatchQueue = .global()

    private static func programmaticallyGenerateIcon(for contractAddress: AlphaWallet.Address, type: TokenType, server: RPCServer, symbol: String) -> TokenImage? {
        guard let i = [TokenObject.numberOfCharactersOfSymbolToShowInIcon, symbol.count].min() else { return nil }
        let symbol = symbol.substring(to: i)
        let rawImage: UIImage

        switch type {
        case .erc1155, .erc721, .erc721ForTickets:
            rawImage = R.image.tokenPlaceholderLarge()!
        case .erc20, .erc875, .nativeCryptocurrency:
            rawImage = programmaticallyGeneratedIconImage(for: contractAddress, server: server)
        }

        return (image: .image(rawImage), symbol: symbol, isFinal: false)
    }

    //Relies on built-in HTTP/HTTPS caching in iOS for the images
    func image(forToken tokenObject: TokenObject) -> Subscribable<TokenImage> {
        return image(contractAddress: tokenObject.contractAddress, server: tokenObject.server, name: tokenObject.symbol.nilIfEmpty ?? tokenObject.name, type: tokenObject.type, balance: tokenObject.balance.first?.balance)
    }

    func image(contractAddress: AlphaWallet.Address, server: RPCServer, name: String) -> Subscribable<TokenImage> {
        // NOTE: not meatter what type we passa as `type`, here we are not going to fetch from OpenSea
        return image(contractAddress: contractAddress, server: server, name: name, type: .erc20, balance: nil)
    }

    private func image(contractAddress: AlphaWallet.Address, server: RPCServer, name: String, type: TokenType, balance: String?) -> Subscribable<TokenImage> {
        let queue = self.queue
        let subscribable: Subscribable<TokenImage>
        let key = "\(contractAddress.eip55String)-\(server.chainID)"
        if let sub = Self.subscribables[key] {
            subscribable = sub
            if let value = sub.value, value.isFinal {
                return subscribable
            }
        } else {
            let sub = Subscribable<TokenImage>(nil)
            Self.subscribables[key] = sub
            subscribable = sub
        }

        if contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            queue.async {
                let generatedImage = Self.programmaticallyGenerateIcon(for: contractAddress, type: type, server: server, symbol: name)

                DispatchQueue.main.async {
                    subscribable.value = generatedImage
                }
            }
            return subscribable
        }

        queue.async {
            let generatedImage = Self.programmaticallyGenerateIcon(for: contractAddress, type: type, server: server, symbol: name)

            DispatchQueue.main.async {
                if subscribable.value == nil {
                    subscribable.value = generatedImage
                }
            }

            Self.fetchFromOpenSea(type, balance: balance, queue: queue).done(on: .main, {
                subscribable.value = (image: $0, symbol: "", isFinal: true)
            }).catch(on: queue) { _ in
                Self.fetchFromAssetGitHubRepo(contractAddress: contractAddress, queue: queue).done(on: .main, {
                    subscribable.value = (image: .image($0), symbol: "", isFinal: false)
                }).catch(on: .main, { _ in
                    subscribable.value = generatedImage
                })
            }
        }

        return subscribable
    }

    private static func fetchFromOpenSea(_ type: TokenType, balance: String?, queue: DispatchQueue) -> Promise<WebImageViewImage> {
        Promise { seal in
            queue.async {
                switch type {
                case .erc721, .erc1155:
                    if let json = balance, let data = json.data(using: .utf8), let openSeaNonFungible = nonFungible(fromJsonData: data) {
                        guard let url = URL(string: openSeaNonFungible.contractImageUrl) ?? URL(string: openSeaNonFungible.thumbnailUrl) else {
                            return seal.reject(ImageAvailabilityError.notAvailable)
                        }
                        return seal.fulfill(.url(url))
                    } else {
                        seal.reject(ImageAvailabilityError.notAvailable)
                    }
                case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
                    seal.reject(ImageAvailabilityError.notAvailable)
                }
            }
        }
    }

    private static func fetchFromAssetGitHubRepo(_ githubAssetsSource: GithubAssetsURLResolver.Source, contractAddress: AlphaWallet.Address, queue: DispatchQueue) -> Promise<UIImage> {
        firstly {
            GithubAssetsURLResolver().resolve(for: githubAssetsSource, contractAddress: contractAddress)
        }.then(on: queue, { request -> Promise<UIImage> in
            fetch(request: request, queue: queue)
        })
    }

    private static func fetchFromAssetGitHubRepo(contractAddress: AlphaWallet.Address, queue: DispatchQueue) -> Promise<UIImage> {
        firstly {
            fetchFromAssetGitHubRepo(.alphaWallet, contractAddress: contractAddress, queue: queue)
        }.recover(on: queue, { _ -> Promise<UIImage> in
            fetchFromAssetGitHubRepo(.thirdParty, contractAddress: contractAddress, queue: queue)
        })
    }

    private static func fetch(request: URLRequest, queue: DispatchQueue) -> Promise<UIImage> {
        Alamofire.request(request).responseData().map(on: queue) { response -> UIImage in
            if let img = UIImage(data: response.data) {
                return img
            } else {
                throw ImageAvailabilityError.notAvailable
            }
        }.recover { error -> Promise<UIImage> in
            //This is expected. Some tokens will not have icons
            if let url = request.url?.absoluteString {
                verbose("Loading token icon URL: \(url) error")
            } else {
                verbose("Loading token icon URL: nil error")
            }
            throw error
        }
    }
}

class GithubAssetsURLResolver {
    static let file = "logo.png"

    enum Source: String {
        case alphaWallet = "https://raw.githubusercontent.com/alphawallet/iconassets/master/"
        case thirdParty = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/"
    }

    enum AnyError: Error {
        case case1
    }

    func resolve(for githubAssetsSource: GithubAssetsURLResolver.Source, contractAddress: AlphaWallet.Address) -> Promise<URLRequest> {
        let value = githubAssetsSource.rawValue + contractAddress.eip55String + "/" + GithubAssetsURLResolver.file

        guard let url = URL(string: value) else {
            verbose("Loading token icon URL: \(value) error")
            return .init(error: AnyError.case1)
        }
        let request = URLRequest(url: url)
        return .value(request)
    }
}
