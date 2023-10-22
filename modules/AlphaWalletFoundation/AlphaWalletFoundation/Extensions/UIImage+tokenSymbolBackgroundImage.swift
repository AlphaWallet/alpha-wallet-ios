//
//  UIImage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import UIKit
import AlphaWalletCore

//TODO move contents of this extension out to an actor for protecting the dictionary
extension UIImage {
    static var tokenSymbolBackgroundImageCache: AtomicDictionary<UIColor, UIImage> = .init()
    static func tokenSymbolBackgroundImage(backgroundColor: UIColor, contractAddress: AlphaWallet.Address) -> UIImage {
        if let cachedValue = tokenSymbolBackgroundImageCache[backgroundColor] {
            return cachedValue
        }
        let size = CGSize(width: 40, height: 40)
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(backgroundColor.cgColor)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fill)
        }
        tokenSymbolBackgroundImageCache[backgroundColor] = image
        return image
    }

    public static func tokenSymbolBackgroundImage(backgroundColor: UIColor) -> UIImage {
        if let cachedValue = tokenSymbolBackgroundImageCache[backgroundColor] {
            return cachedValue
        }
        let size = CGSize(width: 40, height: 40)
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(backgroundColor.cgColor)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fill)
        }
        tokenSymbolBackgroundImageCache[backgroundColor] = image
        return image
    }
}
