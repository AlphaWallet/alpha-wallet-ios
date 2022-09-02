// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit
import Kingfisher
import AlphaWalletFoundation

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

final class WebImageView: UIView, ContentBackgroundSupportable {

    private lazy var placeholderImageView: FixedContentModeImageView = {
        let imageView = FixedContentModeImageView(fixedContentMode: contentMode)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = backgroundColor
        imageView.isHidden = true
        imageView.rounding = .none

        return imageView
    }()

    private lazy var imageView: FixedContentModeImageView = {
        let imageView = FixedContentModeImageView(fixedContentMode: contentMode)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = backgroundColor

        return imageView
    }()

    private lazy var svgImageView: SvgImageView = {
        let imageView = SvgImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.rounding = rounding
        imageView.backgroundColor = backgroundColor
        return imageView
    }()

    private var pendingLoadWebViewOperation: BlockOperation?

    override var contentMode: UIView.ContentMode {
        didSet { imageView.fixedContentMode = contentMode }
    }

    var rounding: ViewRounding = .none {
        didSet { imageView.rounding = rounding; svgImageView.rounding = rounding; }
    }

    var contentBackgroundColor: UIColor? {
        didSet { imageView.backgroundColor = contentBackgroundColor; }
    }

    init(edgeInsets: UIEdgeInsets = .zero) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true

        addSubview(imageView)
        addSubview(svgImageView)
        addSubview(placeholderImageView)

        NSLayoutConstraint.activate([
            svgImageView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            placeholderImageView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            imageView.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(image: UIImage?, placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        placeholderImageView.image = placeholder
        svgImageView.alpha = 0
        imageView.image = image
        placeholderImageView.isHidden = imageView.image != nil
    }

    func setImage(url: WebImageURL?, placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        placeholderImageView.image = placeholder

        guard let url = url?.url else {
            svgImageView.alpha = 0
            imageView.image = nil

            placeholderImageView.isHidden = false
            return
        }

        if url.pathExtension == "svg" {
            imageView.image = nil
            placeholderImageView.isHidden = !svgImageView.pageHasLoaded
            svgImageView.setImage(url: url, completion: { [placeholderImageView] in
                placeholderImageView.isHidden = true
            })
        } else {
            svgImageView.alpha = 0
            placeholderImageView.isHidden = imageView.image != nil
            //NOTE: not quite sure, but we need to cancel prev loading operation, othervise we receive an error `notCurrentSourceTask`
            cancel()

            let size = bounds.size.width.isZero ? CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width) : bounds.size
            let processor = DownsamplingImageProcessor(size: size)

            imageView.kf.setImage(with: url, options: [
                .processor(processor),
                .scaleFactor(UIScreen.main.scale),
                .cacheOriginalImage,
                .keepCurrentImageWhileLoading,
                .alsoPrefetchToMemory,
                .loadDiskFileSynchronously
            ], completionHandler: { [imageView, placeholderImageView] result in
                switch result {
                case .success(let res):
                    imageView.image = res.image
                case .failure:
                    imageView.image = nil
                }

                placeholderImageView.isHidden = imageView.image != nil
            })
        }
    }

    func cancel() {
        svgImageView.stopLoading()
        imageView.image = nil
        imageView.kf.cancelDownloadTask()
    }
}
