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

        fetchFromOpenSea(tokenObject).done {
            subscribable.value = (image: $0, symbol: "")
        }.catch { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.fetchFromAssetGitHubRepo(tokenObject).done {
                subscribable.value = (image: $0, symbol: "")
            }.catch { [weak self] _ in
                guard let strongSelf = self else { return }
                subscribable.value = strongSelf.programmaticallyGenerateIcon(forToken: tokenObject)
            }
        }

        return subscribable
    }

    private func fetchFromOpenSea(_ tokenObject: TokenObject) -> Promise<UIImage> {
        Promise { seal in
            switch tokenObject.type {
            case .erc721:
                if let json = tokenObject.balance.first?.balance, let data = json.data(using: .utf8), let openSeaNonFungible = try? JSONDecoder().decode(OpenSeaNonFungible.self, from: data), !openSeaNonFungible.contractImageUrl.isEmpty {
                    let request = URLRequest(url: URL(string: openSeaNonFungible.contractImageUrl)!)
                    fetch(request: request).done { image in
                        seal.fulfill(image)
                    }.catch { error in
                        seal.reject(ImageAvailabilityError.notAvailable)
                    }
                }
            case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
                seal.reject(ImageAvailabilityError.notAvailable)
            }
        }
    }

    private func fetchFromAssetGitHubRepo(_ tokenObject: TokenObject) -> Promise<UIImage> {
        Promise { seal in
            let request = URLRequest(url: URL(string: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/\(tokenObject.contractAddress.eip55String)/logo.png")!)
            fetch(request: request).done { image in
                seal.fulfill(image)
            }.catch { error in
                seal.reject(ImageAvailabilityError.notAvailable)
            }
        }
    }

    private func fetch(request: URLRequest) -> Promise<UIImage> {
        Promise { seal in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
