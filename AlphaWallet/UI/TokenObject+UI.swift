// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import PromiseKit

typealias TokenImage = (image: UIImage, symbol: String)

extension TokenObject {
    fileprivate static let numberOfCharactersOfSymbolToShowInIcon = 4

    fileprivate var programmaticallyGeneratedIconImage: UIImage {
        UIView.tokenSymbolBackgroundImage(backgroundColor: symbolBackgroundColor)
    }

    private var symbolBackgroundColor: UIColor {
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

    var icon: Subscribable<TokenImage> {
        switch type {
        case .nativeCryptocurrency:
            if let img = server.iconImage {
                return .init((image: img, symbol: ""))
            }
        case .erc20, .erc875, .erc721, .erc721ForTickets:
            if let img = contractAddress.tokenImage {
                return .init((image: img, symbol: ""))
            }
        }
        return TokenImageFetcher.instance.image(forToken: self)
    }
}

private class TokenImageFetcher {
    private enum ImageAvailabilityError: LocalizedError {
        case notAvailable
    }

    static var instance = TokenImageFetcher()

    private var subscribables: [String: Subscribable<TokenImage>] = .init()

    private func programmaticallyGenerateIcon(forToken tokenObject: TokenObject) -> TokenImage {
        let i = [TokenObject.numberOfCharactersOfSymbolToShowInIcon, tokenObject.symbol.count].min()!
        let symbol = tokenObject.symbol.substring(to: i)
        return (image: tokenObject.programmaticallyGeneratedIconImage, symbol: symbol)
    }

    //Relies on built-in HTTP/HTTPS caching in iOS for the images
    func image(forToken tokenObject: TokenObject) -> Subscribable<TokenImage> {
        let subscribable: Subscribable<TokenImage>
        let key = "\(tokenObject.contractAddress.eip55String)-\(tokenObject.server.chainID)"
        if let sub = subscribables[key] {
            subscribable = sub
        } else {
            let sub = Subscribable<TokenImage>(nil)
            subscribables[key] = sub
            subscribable = sub
        }

        if tokenObject.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            subscribable.value = programmaticallyGenerateIcon(forToken: tokenObject)
            return subscribable
        }
        
        let githubAssetsSource = tokenObject.server.githubAssetsSource
        let contractAddress = tokenObject.contractAddress
        let balance = tokenObject.balance.first?.balance
        let generatedImage = programmaticallyGenerateIcon(forToken: tokenObject)

        fetchFromOpenSea(tokenObject.type, balance: balance).done {
            subscribable.value = (image: $0, symbol: "")
        }.catch { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.fetchFromAssetGitHubRepo(githubAssetsSource, contractAddress: contractAddress).done {
                subscribable.value = (image: $0, symbol: "")
            }.catch { _ in
                subscribable.value = generatedImage
            }
        }

        return subscribable
    }

    private func fetchFromOpenSea(_ type: TokenType, balance: String?) -> Promise<UIImage> {
        Promise { seal in
            switch type {
            case .erc721:
                if let json = balance, let data = json.data(using: .utf8), let openSeaNonFungible = try? JSONDecoder().decode(OpenSeaNonFungible.self, from: data), !openSeaNonFungible.contractImageUrl.isEmpty {
                    let request = URLRequest(url: URL(string: openSeaNonFungible.contractImageUrl)!)
                    fetch(request: request).done { image in
                        seal.fulfill(image)
                    }.catch { _ in
                        seal.reject(ImageAvailabilityError.notAvailable)
                    }
                }
            case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
                seal.reject(ImageAvailabilityError.notAvailable)
            }
        }
    }

    private func fetchFromAssetGitHubRepo(_ githubAssetsSource: GithubAssetsURLResolver.Source, contractAddress: AlphaWallet.Address) -> Promise<UIImage> {
        return GithubAssetsURLResolver().resolve(for: githubAssetsSource, contractAddress: contractAddress).then { request -> Promise<UIImage> in
            self.fetch(request: request)
        }
    }

    private func fetch(request: URLRequest) -> Promise<UIImage> {
        Promise { seal in
            let task = URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data {
                    let image = UIImage(data: data)
                    if let img = image {
                        seal.fulfill(img)
                    } else {
                        seal.reject(ImageAvailabilityError.notAvailable)
                    }
                } else {
                    seal.reject(ImageAvailabilityError.notAvailable)
                }
            }
            task.resume()
        }
    }
}

class GithubAssetsURLResolver {
    static let file = "logo.png"

    enum Source: String {
        case testNetTokensSource = "https://raw.githubusercontent.com/alphawallet/iconassets/master/"
        case allTokensSource = "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/"
    }

    enum AnyError: Error {
        case case1
    }

    func resolve(for githubAssetsSource: GithubAssetsURLResolver.Source, contractAddress: AlphaWallet.Address) -> Promise<URLRequest> {
        let value = githubAssetsSource.rawValue + contractAddress.eip55String + "/" + GithubAssetsURLResolver.file

        guard let url = URL(string: value) else {
            return .init(error: AnyError.case1)
        }
        let request = URLRequest(url: url)
        return .value(request)
    }
}

fileprivate extension RPCServer {

    var githubAssetsSource: GithubAssetsURLResolver.Source {
        switch self {
        case .rinkeby, .ropsten, .sokol, .kovan, .goerli:
            return .testNetTokensSource
        case .main, .poa, .classic, .callisto, .xDai, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet:
            return .allTokensSource
        }
    }
}
