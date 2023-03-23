//
//  ImageOrWebImageUrl.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit

public enum ImageOrWebImageUrl<T> {
    case url(WebImageURL)
    case image(T)
}

public enum RawImage {
    case generated(image: UIImage, symbol: String)
    case loaded(image: UIImage)
    case none
}
