// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class ImageView: UIImageView {
    private var subscriptionKey: Subscribable<Image>.SubscribableKey?
    var subscribable: Subscribable<Image>? {
        didSet {
            if let previousSubscribable = oldValue, let subscriptionKey = subscriptionKey {
                previousSubscribable.unsubscribe(subscriptionKey)
            }

            if let subscribable = subscribable {
                image = nil
                subscriptionKey = subscribable.subscribe { [weak self] image in
                    self?.image = image
                }
            } else {
                subscriptionKey = nil
                image = nil
            }
        }
    }
}

class TokenImageView: UIView {
    private var subscriptionKey: Subscribable<TokenImage>.SubscribableKey?
    private let symbolLabel: UILabel = {
        let label = UILabel()
        label.textColor = Colors.appWhite
        label.font = UIFont.systemFont(ofSize: 13)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    private lazy var imageView: WebImageView = {
        let imageView = WebImageView()
        return imageView
    }()

    private var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
    }

    var subscribable: Subscribable<TokenImage>? {
        didSet {
            if let previousSubscribable = oldValue, let subscriptionKey = subscriptionKey {
                previousSubscribable.unsubscribe(subscriptionKey)
            }

            if let subscribable = subscribable {
                if subscribable.value == nil {
                    imageView.setImage(url: nil, placeholder: tokenImagePlaceholder)
                }

                subscriptionKey = subscribable.subscribe { [weak self] imageAndSymbol in
                    guard let strongSelf = self else { return }
                    switch imageAndSymbol?.image {
                    case .image(let v):
                        strongSelf.imageView.setImage(image: v)
                    case .url(let v):
                        strongSelf.imageView.setImage(url: v, placeholder: strongSelf.tokenImagePlaceholder)
                    case .none:
                        strongSelf.imageView.setImage(url: nil, placeholder: strongSelf.tokenImagePlaceholder)
                    }
                    strongSelf.symbolLabel.text = imageAndSymbol?.symbol ?? ""
                }
            } else {
                subscriptionKey = nil
                imageView.setImage(url: nil, placeholder: tokenImagePlaceholder)
                symbolLabel.text = ""
            }
        }
    }

    init(edgeInsets: UIEdgeInsets = .zero) {
        super.init(frame: .zero)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        symbolLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(symbolLabel)

        NSLayoutConstraint.activate([
            symbolLabel.anchorsConstraint(to: imageView),

            imageView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

