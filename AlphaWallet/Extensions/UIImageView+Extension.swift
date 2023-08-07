//
//  UIImageView+Extension.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.11.2021.
//

import Foundation
import Kingfisher

extension UIImageView {

    func setImage(url urlValue: URL?, placeholder: UIImage? = .none) {
        if let url = urlValue {
            let resource = Kingfisher.ImageResource(downloadURL: url)
            var options: KingfisherOptionsInfo = []

            if let value = placeholder {
                options.append(.onFailureImage(value))
            }

            kf.setImage(with: resource, placeholder: placeholder, options: options)
        } else {
            image = placeholder
        }
    }
}
