// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import WebKit
import Kingfisher
import AlphaWalletFoundation
import Combine

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
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        cornerRadius = rounding.cornerRadius(view: self)
    }
}

//TODO: rename maybe, as its actually not image view
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

    //We always use the optional version unless we want to assign an image to it, that's when the lazy-var creation (needs to) kicks in; because it's a web view
    private var svgImageView: SvgImageView?
    private var videoPlayerView: AVPlayerView?

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false

        return indicator
    }()

    override var contentMode: UIView.ContentMode {
        didSet { imageView.fixedContentMode = contentMode }
    }

    var rounding: ViewRounding = .none {
        didSet {
            imageView.rounding = rounding
            svgImageView?.rounding = rounding
            videoPlayerView?.rounding = rounding
        }
    }

    var placeholderRounding: ViewRounding = .none {
        didSet { placeholderImageView.rounding = placeholderRounding }
    }

    @Published var loading: ViewLoading = .enabled

    var contentBackgroundColor: UIColor? {
        didSet { imageView.backgroundColor = contentBackgroundColor; }
    }
    private let playButtonPositioning: AVPlayerView.PlayButtonPositioning
    private let setContentSubject = PassthroughSubject<WebImageViewModel.SetContentEvent, Never>()
    private var cancellable = Set<AnyCancellable>()
    private let viewModel: WebImageViewModel
    private let edgeInsets: UIEdgeInsets

    init(edgeInsets: UIEdgeInsets = .zero, playButtonPositioning: AVPlayerView.PlayButtonPositioning, viewModel: WebImageViewModel = .init()) {
        self.edgeInsets = edgeInsets
        self.viewModel = viewModel
        self.playButtonPositioning = playButtonPositioning
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = true

        addSubview(imageView)
        addSubview(placeholderImageView)
        addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            placeholderImageView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            imageView.anchorsConstraint(to: self, edgeInsets: edgeInsets),

            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        bind(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(image: UIImage?, placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        placeholderImageView.image = placeholder
        setContentSubject.send(.image(image))
    }

    func setImage(url: WebImageURL?, placeholder: UIImage? = R.image.tokenPlaceholderLarge()) {
        placeholderImageView.image = placeholder
        setContentSubject.send(.url(url?.url))
    }

    private func bind(viewModel: WebImageViewModel) {
        let input = WebImageViewModelInput(
            loadUrl: setContentSubject.eraseToAnyPublisher(),
            viewLoading: $loading.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState
            .sink { [weak self] in self?.reload(viewState: $0) }
            .store(in: &cancellable)

        output.isPlaceholderHiddenWhenVideoLoaded
            .assign(to: \.isHidden, on: placeholderImageView)
            .store(in: &cancellable)

        output.loadingViewAlpha
            .sink { [weak loadingIndicator, weak videoPlayerView] in
                loadingIndicator?.alpha = $0
                videoPlayerView?.loadingIndicator.alpha = $0
            }.store(in: &cancellable)
    }

    private func reload(viewState: WebImageViewModel.ViewState) {
        switch viewState {
        case .loading:
            svgImageView?.alpha = 0
            imageView.image = nil
            videoPlayerView?.alpha = 0
            placeholderImageView.isHidden = false
            videoPlayerView?.cancel()
            loadingIndicator.startAnimating()
        case .noContent:
            svgImageView?.alpha = 0
            imageView.image = nil
            videoPlayerView?.alpha = 0

            placeholderImageView.isHidden = false
            videoPlayerView?.cancel()
            loadingIndicator.stopAnimating()
        case .content(let data):
            loadingIndicator.stopAnimating()
            switch data {
            case .svg(let svg):
                imageView.image = nil
                createSvgImageView()
                svgImageView?.setImage(svg: svg)
                placeholderImageView.isHidden = true
                videoPlayerView?.cancel()
            case .image(let image):
                imageView.image = image
                svgImageView?.alpha = 0
                videoPlayerView?.alpha = 0
                placeholderImageView.isHidden = true
                videoPlayerView?.cancel()
            case .video(let video):
                svgImageView?.alpha = 0
                createVideoPlayerView()
                videoPlayerView?.alpha = 1

                imageView.image = video.preview
                placeholderImageView.isHidden = video.preview != nil

                videoPlayerView?.play(url: video.url)
            }
        }
    }

    func cancel() {
        setContentSubject.send(.cancel)
    }

    private func createSvgImageView() {
        let imageView = SvgImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = backgroundColor
        imageView.rounding = rounding
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])
        svgImageView = imageView
    }

    private func createVideoPlayerView() {
        let view = AVPlayerView(edgeInsets: .zero, playButtonPositioning: playButtonPositioning, viewModel: viewModel.avPlayerViewModel)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.rounding = rounding
        addSubview(view)
        NSLayoutConstraint.activate([
            view.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])
        videoPlayerView = view
    }
}
