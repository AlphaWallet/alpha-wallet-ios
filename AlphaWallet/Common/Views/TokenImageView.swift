// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import Combine

final class TokenImageView: UIView, ViewRoundingSupportable, ViewLoadingSupportable {

    private let playButtonPositioning: AVPlayerView.PlayButtonPositioning
    private let symbolLabel: ResponsiveLabel = {
        let label = ResponsiveLabel()
        label.textColor = Configuration.Color.Semantic.defaultInverseText
        label.font = UIFont.systemFont(ofSize: 13)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true

        return label
    }()
    private (set) lazy var imageView: WebImageView = {
        let imageView = WebImageView(playButtonPositioning: playButtonPositioning)
        imageView.rounding = rounding

        return imageView
    }()
    private lazy var chainOverlayImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    private var tokenImagePlaceholder: UIImage? = {
        return R.image.tokenPlaceholderLarge()
    }()

    var isChainOverlayHidden: Bool = false {
        didSet { chainOverlayImageView.isHidden = isChainOverlayHidden }
    }

    var isSymbolLabelHidden: Bool = false {
        didSet { symbolLabel.isHidden = isSymbolLabelHidden }
    }

    var rounding: ViewRounding = .circle {
        didSet { imageView.rounding = rounding }
    }
    var placeholderRounding: ViewRounding = .none {
        didSet { imageView.placeholderRounding = placeholderRounding }
    }

    var loading: ViewLoading = .enabled {
        didSet { imageView.loading = loading }
    }

    override var contentMode: UIView.ContentMode {
        didSet { imageView.contentMode = contentMode }
    }

    private let imageSourceSubject = PassthroughSubject<TokenImagePublisher, Never>()
    private var cancellable = Set<AnyCancellable>()

    init(edgeInsets: UIEdgeInsets = .zero, playButtonPositioning: AVPlayerView.PlayButtonPositioning = .center) {
        self.playButtonPositioning = playButtonPositioning
        super.init(frame: .zero)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        chainOverlayImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chainOverlayImageView)

        symbolLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(symbolLabel)

        isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            symbolLabel.anchorsConstraint(to: imageView),

            imageView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            chainOverlayImageView.leftAnchor.constraint(equalTo: imageView.leftAnchor, constant: 0),
            chainOverlayImageView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 0),
            chainOverlayImageView.sized(DataEntry.Metric.ChainOverlay.size),
        ])

        chainOverlayImageView.isHidden = isChainOverlayHidden

        imageSourceSubject.flatMapLatest { $0 }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                self?.symbolLabel.text = ""

                switch value?.image {
                case .image(let imageType):
                    switch imageType {
                    case .generated(let image, let symbol):
                        self?.symbolLabel.text = symbol
                        self?.imageView.setImage(image: image, placeholder: self?.tokenImagePlaceholder)
                    case .loaded(let image):
                        self?.imageView.setImage(image: image, placeholder: self?.tokenImagePlaceholder)
                    case .none:
                        self?.imageView.setImage(url: nil, placeholder: self?.tokenImagePlaceholder)
                    }
                case .url(let url):
                    self?.imageView.setImage(url: url, placeholder: self?.tokenImagePlaceholder)
                case .none:
                    self?.imageView.setImage(url: nil, placeholder: self?.tokenImagePlaceholder)
                }

                self?.chainOverlayImageView.image = value?.overlayServerIcon
            }).store(in: &cancellable)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(imageSource: TokenImagePublisher) {
        imageSourceSubject.send(imageSource)
    }

    func cancel() {
        imageView.cancel()
    }
}

private class ResponsiveLabel: UILabel {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return false
    }
}
