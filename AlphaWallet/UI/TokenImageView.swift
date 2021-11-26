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
    private var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    var subscribable: Subscribable<TokenImage>? {
        didSet {
            if let previousSubscribable = oldValue, let subscriptionKey = subscriptionKey {
                previousSubscribable.unsubscribe(subscriptionKey)
            }

            if let subscribable = subscribable {
                imageView.image = nil
                subscriptionKey = subscribable.subscribe { [weak self] imageAndSymbol  in
                    guard let strongSelf = self else { return }
                    strongSelf.imageView.image = imageAndSymbol?.image
                    strongSelf.symbolLabel.text = imageAndSymbol?.symbol ?? ""
                }
            } else {
                subscriptionKey = nil
                imageView.image = nil
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
        imageView.layer.cornerRadius = imageView.frame.size.height / 2
        imageView.clipsToBounds = true
        NSLayoutConstraint.activate([
            symbolLabel.anchorsConstraint(to: imageView),

            imageView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

