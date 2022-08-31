//
//  ImageOrWebImageUrl.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.05.2022.
//

import UIKit

public enum ImageOrWebImageUrl {
    case url(WebImageURL)
    case image(UIImage?)
}
