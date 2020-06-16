// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

extension TokenObject {
    private static let numberOfCharactersOfSymbolToShow = 4

    private var programmaticallyGeneratedIconImage: UIImage {
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

    var icon: (image: UIImage, symbol: String) {
        let image: UIImage?

        switch type {
        case .nativeCryptocurrency:
            image = server.iconImage
        case .erc20, .erc875, .erc721, .erc721ForTickets:
            image = nil
        }

        if let img = image {
            return (image: img, symbol: "")
        } else {
            let i = [TokenObject.numberOfCharactersOfSymbolToShow, symbol.count].min()!
            return (image: programmaticallyGeneratedIconImage, symbol: symbol.substring(to: i))
        }
    }
}
