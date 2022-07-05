// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import PromiseKit
import AlphaWalletCore
import AlphaWalletOpenSea
import Kingfisher

typealias GoogleContentSize = AlphaWalletCore.GoogleContentSize
typealias WebImageURL = AlphaWalletCore.WebImageURL
typealias TokenImage = (image: ImageOrWebImageUrl, symbol: String, isFinal: Bool, overlayServerIcon: UIImage?)
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
}

class RPCServerImageFetcher {
    static var instance = RPCServerImageFetcher()

    private static var subscribables: AtomicDictionary<Int, Subscribable<Image>> = .init()

    func image(server: RPCServer) -> Subscribable<Image> {
        if let sub = Self.subscribables[server.chainID] {
            return sub
        } else {
            let sub = Subscribable<Image>(nil)
            Self.subscribables[server.chainID] = sub

            sub.value = server.iconImage ?? R.image.tokenPlaceholderLarge()!

            return sub
        }
    }
}

extension HasTokenImage {

    func icon(withSize size: GoogleContentSize) -> Subscribable<TokenImage> {
        let name = symbol.nilIfEmpty ?? name
        return TokenImageFetcher.instance.image(contractAddress: contractAddress, server: server, name: name, type: type, balance: firstNftAsset, size: size)
    }
}

protocol HasTokenImage {
    var name: String { get }
    var symbol: String { get }
    var contractAddress: AlphaWallet.Address { get }
    var type: TokenType { get }
    var server: RPCServer { get }
    var firstNftAsset: NonFungibleFromJson? { get }
}

extension Token: HasTokenImage {
    var firstNftAsset: NonFungibleFromJson? {
        balance.compactMap { $0.nonFungibleBalance }.first
    }
}

extension TokenViewModel: HasTokenImage {
    var firstNftAsset: NonFungibleFromJson? {
        balance.balance.compactMap { $0.nonFungibleBalance }.first
    }
}

extension PopularToken: HasTokenImage {
    var symbol: String { "" }
    var type: TokenType { .erc20 }
    var firstNftAsset: NonFungibleFromJson? { nil }
}

class TokenImageFetcher {
    enum ImageAvailabilityError: LocalizedError {
        case notAvailable
    }

    static var instance = TokenImageFetcher()

    private static var subscribables: AtomicDictionary<String, Subscribable<TokenImage>> = .init()

    private static func programmaticallyGenerateIcon(for contractAddress: AlphaWallet.Address, type: TokenType, server: RPCServer, symbol: String) -> TokenImage? {
        guard let i = [Constants.Image.numberOfCharactersOfSymbolToShowInIcon, symbol.count].min() else { return nil }
        let symbol = symbol.substring(to: i)
        let rawImage: UIImage?
        let overlayServerIcon: UIImage?

        switch type {
        case .erc1155, .erc721, .erc721ForTickets:
            rawImage = nil
            overlayServerIcon = server.staticOverlayIcon
        case .erc20, .erc875:
            rawImage = programmaticallyGeneratedIconImage(for: contractAddress, server: server)
            overlayServerIcon = server.staticOverlayIcon
        case .nativeCryptocurrency:
            rawImage = programmaticallyGeneratedIconImage(for: contractAddress, server: server)
            overlayServerIcon = nil
        }

        return (image: .image(rawImage), symbol: symbol, isFinal: false, overlayServerIcon: overlayServerIcon)
    }

    private func getDefaultOrGenerateIcon(server: RPCServer, contractAddress: AlphaWallet.Address, type: TokenType, name: String) -> TokenImage? {
        switch type {
        case .nativeCryptocurrency:
            if let img = server.iconImage {
                return (image: .image(img), symbol: "", isFinal: true, overlayServerIcon: nil)
            }
        case .erc20, .erc875, .erc721, .erc721ForTickets, .erc1155:
            if let img = contractAddress.tokenImage {
                return (image: .image(img), symbol: "", isFinal: true, overlayServerIcon: server.staticOverlayIcon)
            }
        }

        return TokenImageFetcher.programmaticallyGenerateIcon(for: contractAddress, type: type, server: server, symbol: name)
    }

    func image(contractAddress: AlphaWallet.Address, server: RPCServer, name: String, type: TokenType, balance: NonFungibleFromJson?, size: GoogleContentSize) -> Subscribable<TokenImage> {
        let subscribable: Subscribable<TokenImage>
        let key = "\(contractAddress.eip55String)-\(server.chainID)-\(size.rawValue)"
        if let sub = TokenImageFetcher.subscribables[key] {
            subscribable = sub
            if let value = sub.value, value.isFinal {
                return subscribable
            }
        } else {
            let sub = Subscribable<TokenImage>(nil)
            TokenImageFetcher.subscribables[key] = sub
            subscribable = sub
        }

        let generatedImage = getDefaultOrGenerateIcon(server: server, contractAddress: contractAddress, type: type, name: name)
        if contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            subscribable.value = generatedImage
            return subscribable
        }

        if subscribable.value == nil {
            subscribable.value = generatedImage
        }

        if let image = generatedImage, image.isFinal {
            return subscribable
        }

        firstly {
            TokenImageFetcher
                .fetchFromAssetGitHubRepo(.alphaWallet, contractAddress: contractAddress)
                .map { image -> TokenImage in
                    return (image: .image(image), symbol: "", isFinal: true, overlayServerIcon: server.staticOverlayIcon)
                }
        }.recover { _ -> Promise<TokenImage> in
            let url = try TokenImageFetcher.imageUrlFromOpenSea(type, balance: balance, size: size)
            return .value((image: url, symbol: "", isFinal: true, overlayServerIcon: server.staticOverlayIcon))
        }.recover { _ -> Promise<TokenImage> in
            return TokenImageFetcher
                .fetchFromAssetGitHubRepo(.thirdParty, contractAddress: contractAddress)
                .map { image -> TokenImage in
                    return (image: .image(image), symbol: "", isFinal: false, overlayServerIcon: server.staticOverlayIcon)
                }
        }.done { value in
            subscribable.value = value
        }.catch { _ in
            subscribable.value = generatedImage
        }

        return subscribable
    }

    private static func imageUrlFromOpenSea(_ type: TokenType, balance: NonFungibleFromJson?, size: GoogleContentSize) throws -> ImageOrWebImageUrl {
        switch type {
        case .erc721, .erc1155:
            guard let openSeaNonFungible = balance, let url = openSeaNonFungible.nonFungibleImageUrl(rewriteGoogleContentSizeUrl: size) else {
                throw ImageAvailabilityError.notAvailable
            }
            return .url(url)
        case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            throw ImageAvailabilityError.notAvailable
        }
    }

    private static func fetchFromAssetGitHubRepo(_ githubAssetsSource: GithubAssetsURLResolver.Source, contractAddress: AlphaWallet.Address) -> Promise<UIImage> {
        struct AnyError: Error { }
        let urlString = githubAssetsSource.url(forContract: contractAddress)
        guard let url = URL(string: urlString) else {
            verboseLog("Loading token icon URL: \(urlString) error")
            return .init(error: AnyError())
        }
        let resource = ImageResource(downloadURL: url, cacheKey: urlString)

        return Promise { seal in
            KingfisherManager.shared.retrieveImage(with: resource) { result in
                switch result {
                case .success(let response):
                    seal.fulfill(response.image)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}

class GithubAssetsURLResolver {
    static let file = "logo.png"

    enum Source: String {
        case alphaWallet = "https://raw.githubusercontent.com/AlphaWallet/iconassets/lowercased/"
        case thirdParty = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/"

        func url(forContract contract: AlphaWallet.Address) -> String {
            switch self {
            case .alphaWallet:
                return rawValue + contract.eip55String.lowercased() + "/" + GithubAssetsURLResolver.file
            case .thirdParty:
                return rawValue + contract.eip55String + "/" + GithubAssetsURLResolver.file
            }
        }
    }
}
