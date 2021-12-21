//
//  BlockieImageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.11.2020.
//

import UIKit

class BlockieImageView: UIView {
    private var subscriptionKey: Subscribable<BlockiesImage>.SubscribableKey?
    private lazy var imageView = WebImageView()

    var subscribable: Subscribable<BlockiesImage>? {
        didSet {
            if let previousSubscribable = oldValue, let subscriptionKey = subscriptionKey {
                previousSubscribable.unsubscribe(subscriptionKey)
            }

            if let subscribable = subscribable {
                subscriptionKey = subscribable.subscribe { [weak self] image in
                    self?.setBlockieImage(image: image)
                }
            } else {
                subscriptionKey = nil
                self.setBlockieImage(image: nil)
            }
        }
    }

    var image: BlockiesImage? {
        get {
            return nil
        }
        set {
            setBlockieImage(image: newValue)
        }
    }

    ///Web view specific size, seems like it cant be the same as view size, each size should be specified manually via brute, for 24x24 image its anougth 100x100 web image view size
    init(size: CGSize) {
        super.init(frame: .zero)

        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([imageView.anchorsConstraint(to: self)])

        imageView.isUserInteractionEnabled = true
        isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: size.width),
            imageView.heightAnchor.constraint(equalToConstant: size.height)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = frame.width / 2.0
    }

    func setBlockieImage(image: BlockiesImage?) {
        switch image {
        case .image(let image, _):
            imageView.setImage(image: image)
        case .url(let url, _):
            imageView.setImage(url: url)
        case .none:
            imageView.setImage(url: nil)
        }
    }

    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        let gesture = UITapGestureRecognizer(target: target, action: action)
        imageView.addGestureRecognizer(gesture)
    }
}

extension BlockieImageView {
    static var defaultBlockieImageView: BlockieImageView {
        return BlockieImageView(size: .init(width: 24, height: 24))
    }
}
