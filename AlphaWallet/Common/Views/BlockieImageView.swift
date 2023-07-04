//
//  BlockieImageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.11.2020.
//

import UIKit
import AlphaWalletFoundation

class BlockieImageView: UIView {
    private lazy var imageView: WebImageView = {
        let imageView = WebImageView(playButtonPositioning: .center)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        imageView.rounding = .circle

        return imageView
    }()

    var hideWhenImageIsNil: Bool = false

    override var contentMode: UIView.ContentMode {
        didSet { imageView.contentMode = contentMode }
    }

    ///Web view specific size, seems like it cant be the same as view size, each size should be specified manually via brute force, for 24x24 image its enough 100x100 web image view size
    init(size: CGSize) {
        super.init(frame: .zero)

        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        contentMode = .scaleAspectFit
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.anchorsConstraint(to: self),
            imageView.widthAnchor.constraint(equalToConstant: size.width),
            imageView.heightAnchor.constraint(equalToConstant: size.height)
        ])
    }

    init(viewSize: CGSize, imageSize: CGSize) {
        super.init(frame: .zero)
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.cornerRadius = imageSize.height/2.0
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),

            imageView.widthAnchor.constraint(equalToConstant: imageSize.width),
            imageView.heightAnchor.constraint(equalToConstant: imageSize.height),

            widthAnchor.constraint(equalToConstant: viewSize.width),
            heightAnchor.constraint(equalToConstant: viewSize.height),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = frame.width / 2.0
    }

    func set(blockieImage: BlockiesImage?) {
        switch blockieImage {
        case .image(let image, _):
            imageView.setImage(image: image)
        case .url(let url, _):
            imageView.setImage(url: url)
        case .none:
            imageView.setImage(url: nil)
        }

        if hideWhenImageIsNil {
            isHidden = blockieImage == nil
        }
    }

    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        let gesture = UITapGestureRecognizer(target: target, action: action)
        imageView.addGestureRecognizer(gesture)
    }
}
