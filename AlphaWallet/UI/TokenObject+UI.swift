// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import PromiseKit

typealias TokenImage = (image: UIImage, symbol: String, isFinal: Bool)

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

extension TokenObject {
    fileprivate static let numberOfCharactersOfSymbolToShowInIcon = 4

    var icon: Subscribable<TokenImage> {
        switch type {
        case .nativeCryptocurrency:
            if let img = server.iconImage {
                return .init((image: img, symbol: "", isFinal: true))
            }
        case .erc20, .erc875, .erc721, .erc721ForTickets, .erc1155:
            if let img = contractAddress.tokenImage {
                return .init((image: img, symbol: "", isFinal: true))
            }
        }
        return TokenImageFetcher.instance.image(forToken: self)
    }
}

class TokenImageFetcher {
    private enum ImageAvailabilityError: LocalizedError {
        case notAvailable
    }

    static var instance = TokenImageFetcher()

    private static var subscribables: ThreadSafeDictionary<String, Subscribable<TokenImage>> = .init()
    private let queue: DispatchQueue = .global()

    private static func programmaticallyGenerateIcon(for contractAddress: AlphaWallet.Address, server: RPCServer, symbol: String) -> TokenImage? {
        guard let i = [TokenObject.numberOfCharactersOfSymbolToShowInIcon, symbol.count].min() else { return nil }
        let symbol = symbol.substring(to: i)
        return (image: programmaticallyGeneratedIconImage(for: contractAddress, server: server), symbol: symbol, isFinal: false)
    }

    //Relies on built-in HTTP/HTTPS caching in iOS for the images
    func image(forToken tokenObject: TokenObject) -> Subscribable<TokenImage> {
        image(contractAddress: tokenObject.contractAddress, server: tokenObject.server, name: tokenObject.symbol, type: tokenObject.type, balance: tokenObject.balance.first?.balance)
    }

    func image(contractAddress: AlphaWallet.Address, server: RPCServer, name: String) -> Subscribable<TokenImage> {
        // NOTE: not meatter what type we passa as `type`, here we are not going to fetch from OpenSea
        image(contractAddress: contractAddress, server: server, name: name, type: .erc20, balance: nil)
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
                let generatedImage = Self.programmaticallyGenerateIcon(for: contractAddress, server: server, symbol: name)

                DispatchQueue.main.async {
                    subscribable.value = generatedImage
                }
            }
            return subscribable
        }

        queue.async {
            let generatedImage = Self.programmaticallyGenerateIcon(for: contractAddress, server: server, symbol: name)
            Self.fetchFromOpenSea(type, balance: balance, queue: queue).done(on: .main, {
                subscribable.value = (image: $0, symbol: "", isFinal: true)
            }).catch(on: queue) { _ in
                Self.fetchFromAssetGitHubRepo(contractAddress: contractAddress, queue: queue).done(on: .main, {
                    subscribable.value = (image: $0, symbol: "", isFinal: false)
                }).catch(on: .main, { _ in
                    subscribable.value = generatedImage
                })
            }
        }

        return subscribable
    }

    private static func fetchFromOpenSea(_ type: TokenType, balance: String?, queue: DispatchQueue) -> Promise<UIImage> {
        Promise { seal in
            queue.async {
                switch type {
                case .erc721, .erc1155:
                    if let json = balance, let data = json.data(using: .utf8), let openSeaNonFungible = nonFungible(fromJsonData: data), !openSeaNonFungible.contractImageUrl.isEmpty {
                        let request = URLRequest(url: URL(string: openSeaNonFungible.contractImageUrl)!)
                        fetch(request: request, queue: queue).done(on: queue, { image in
                            seal.fulfill(image)
                        }).catch(on: queue, { _ in
                            seal.reject(ImageAvailabilityError.notAvailable)
                        })
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
        Promise { seal in
            queue.async {
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
            return .init(error: AnyError.case1)
        }
        let request = URLRequest(url: url)
        return .value(request)
    }
}
