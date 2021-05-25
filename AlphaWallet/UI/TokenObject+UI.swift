// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import PromiseKit

typealias TokenImage = (image: UIImage, symbol: String)

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

class TokenImageFetcher {
    private enum ImageAvailabilityError: LocalizedError {
        case notAvailable
    }

    static var instance = TokenImageFetcher()

    private static var subscribables: ThreadSafeDictionary<String, Subscribable<TokenImage>> = .init()
    private let queue: DispatchQueue = .global()

    private func programmaticallyGenerateIcon(for contractAddress: AlphaWallet.Address, server: RPCServer, symbol: String) -> TokenImage {
        let i = [TokenObject.numberOfCharactersOfSymbolToShowInIcon, symbol.count].min()!
        let symbol = symbol.substring(to: i)
        return (image: programmaticallyGeneratedIconImage(for: contractAddress, server: server), symbol: symbol)
    }

    //Relies on built-in HTTP/HTTPS caching in iOS for the images
    func image(forToken tokenObject: TokenObject) -> Subscribable<TokenImage> {
        let subscribable: Subscribable<TokenImage>
        let key = "\(tokenObject.contractAddress.eip55String)-\(tokenObject.server.chainID)"
        if let sub = Self.subscribables[key] {
            subscribable = sub
        } else {
            let sub = Subscribable<TokenImage>(nil)
            Self.subscribables[key] = sub
            subscribable = sub
        }

        let contractAddress = tokenObject.contractAddress
        let server = tokenObject.server
        let symbol = tokenObject.symbol
        let balance = tokenObject.balance.first?.balance
        let type = tokenObject.type

        if tokenObject.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            queue.async {
                let value = self.programmaticallyGenerateIcon(for: contractAddress, server: server, symbol: symbol)
                
                DispatchQueue.main.async {
                    subscribable.value = value
                }
            }

            return subscribable
        }

        queue.async {
            let generatedImage = self.programmaticallyGenerateIcon(for: contractAddress, server: server, symbol: symbol)

            self.fetchFromOpenSea(type, balance: balance).done(on: .main, {
                subscribable.value = (image: $0, symbol: "")
            }).catch(on: self.queue) { [weak self] _ in
                guard let strongSelf = self else { return }

                strongSelf.fetchFromAssetGitHubRepo(contractAddress: contractAddress).done(on: .main, {
                    subscribable.value = (image: $0, symbol: "")
                }).catch(on: .main, { _ in
                    subscribable.value = generatedImage
                })
            }
        }

        return subscribable
    }

    func image(contractAddress: AlphaWallet.Address, server: RPCServer, name: String) -> Subscribable<TokenImage> {
        let subscribable: Subscribable<TokenImage>
        let key = "\(contractAddress.eip55String)-\(server.chainID)"
        if let sub = Self.subscribables[key] {
            subscribable = sub
        } else {
            let sub = Subscribable<TokenImage>(nil)
            Self.subscribables[key] = sub
            subscribable = sub
        }

        if contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            queue.async {
                let generatedImage = self.programmaticallyGenerateIcon(for: contractAddress, server: server, symbol: name)

                DispatchQueue.main.async {
                    subscribable.value = generatedImage
                }
            }
            return subscribable
        }

        queue.async {
            let generatedImage = self.programmaticallyGenerateIcon(for: contractAddress, server: server, symbol: name)
            
            self.fetchFromAssetGitHubRepo(contractAddress: contractAddress).done(on: .main, {
                subscribable.value = (image: $0, symbol: "")
            }).catch(on: .main, { _ in
                subscribable.value = generatedImage
            })
        }

        return subscribable
    }

    private func fetchFromOpenSea(_ type: TokenType, balance: String?) -> Promise<UIImage> {
        Promise { seal in
            queue.async {
                switch type {
                case .erc721:
                    if let json = balance, let data = json.data(using: .utf8), let openSeaNonFungible = nonFungible(fromJsonData: data), !openSeaNonFungible.contractImageUrl.isEmpty {
                        let request = URLRequest(url: URL(string: openSeaNonFungible.contractImageUrl)!)
                        self.fetch(request: request).done(on: self.queue, { image in
                            seal.fulfill(image)
                        }).catch(on: self.queue, { _ in
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

    private func fetchFromAssetGitHubRepo(_ githubAssetsSource: GithubAssetsURLResolver.Source, contractAddress: AlphaWallet.Address) -> Promise<UIImage> {
        firstly {
            GithubAssetsURLResolver().resolve(for: githubAssetsSource, contractAddress: contractAddress)
        }.then(on: queue, { request -> Promise<UIImage> in
            self.fetch(request: request)
        })
    }

    private func fetchFromAssetGitHubRepo(contractAddress: AlphaWallet.Address) -> Promise<UIImage> {
        firstly {
            fetchFromAssetGitHubRepo(.alphaWallet, contractAddress: contractAddress)
        }.recover(on: queue, { _ -> Promise<UIImage> in
            self.fetchFromAssetGitHubRepo(.thirdParty, contractAddress: contractAddress)
        })
    }

    private func fetch(request: URLRequest) -> Promise<UIImage> {
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
