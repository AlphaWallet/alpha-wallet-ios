// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit
import Kingfisher

final class FixedContentModeImageView: UIImageView {
    var fixedContentMode: UIView.ContentMode {
        didSet { self.layoutSubviews() }
    }

    var rounding: ViewRounding = .none {
        didSet { layoutSubviews() }
    }

    init(fixedContentMode contentMode: UIView.ContentMode) {
        self.fixedContentMode = contentMode
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentMode = fixedContentMode
        layer.masksToBounds = true
        clipsToBounds = true

        switch rounding {
        case .none:
            cornerRadius = 0
        case .circle:
            cornerRadius = bounds.width / 2
        case .custom(let radius):
            cornerRadius = radius
        }
    }
}

final class WebImageView: UIView {

    private lazy var imageView: FixedContentModeImageView = {
        let imageView = FixedContentModeImageView(fixedContentMode: contentMode)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = Colors.appBackground

        return imageView
    }()

    private lazy var svgImageView: SvgImageView = {
        let imageView = SvgImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.rounding = rounding
        imageView.backgroundColor = Colors.appBackground
        return imageView
    }()

    private var pendingLoadWebViewOperation: BlockOperation?

    override var contentMode: UIView.ContentMode {
        didSet { imageView.fixedContentMode = contentMode }
    }

    var rounding: ViewRounding = .none {
        didSet { imageView.rounding = rounding; svgImageView.rounding = rounding; }
    }

    init(placeholder: UIImage? = R.image.tokenPlaceholderLarge(), edgeInsets: UIEdgeInsets = .zero) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        clipsToBounds = true

        addSubview(imageView)
        addSubview(svgImageView)

        NSLayoutConstraint.activate([
            svgImageView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            imageView.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(image: UIImage) {
        svgImageView.alpha = 0
        imageView.image = image.kf.image(withRadius: .point(rounding.cornerRadius(view: self)), fit: image.size)
    }

    func setImage(url: WebImageURL?, placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        guard let url = url?.url else {
            svgImageView.alpha = 0
            imageView.image = placeholder
            return
        }

        if url.pathExtension == "svg" {
            imageView.image = nil
            svgImageView.setImage(url: url)
        } else {
            svgImageView.alpha = 0

            let processor = RoundCornerImageProcessor(cornerRadius: rounding.cornerRadius(view: self))
            var options: KingfisherOptionsInfo = [.processor(processor)]

            if let value = placeholder {
                options.append(.onFailureImage(value))
            }

            imageView.kf.setImage(with: url, placeholder: placeholder, options: options)
        }
    }
}
