//
//  AVPlayerView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.02.2023.
//

import UIKit
import AVKit
import Combine

class AVPlayerView: UIView, ViewRoundingSupportable {

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var videoLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    private var cancelable = Set<AnyCancellable>()
    private let urlSubject = PassthroughSubject<URL?, Never>()
    private let viewModel: AVPlayerViewModel

    private lazy var playStopButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .lightGray

        return button
    }()

    lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false

        return indicator
    }()

    var rounding: ViewRounding = .none {
        didSet { layoutSubviews() }
    }

    var placeholderRounding: ViewRounding = .none

    init(edgeInsets: UIEdgeInsets = .zero,
         playButtonPositioning: PlayButtonPositioning,
         viewModel: AVPlayerViewModel) {

        self.viewModel = viewModel
        super.init(frame: .zero)
        
        videoLayer.videoGravity = .resizeAspectFill
        videoLayer.player = viewModel.player
        isUserInteractionEnabled = true

        addSubview(playStopButton)
        addSubview(loadingIndicator)

        let playStopButtonCointraints: [NSLayoutConstraint]
        switch playButtonPositioning {
        case .bottomRight:
            playStopButtonCointraints = [
                playStopButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                playStopButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
            ]
        case .center:
            playStopButtonCointraints = [
                playStopButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                playStopButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            ]
        }

        NSLayoutConstraint.activate([
            playStopButton.sized(CGSize(width: 30, height: 30)),

            playStopButtonCointraints,
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: AVPlayerViewModel) {
        let input = AVPlayerViewModelInput(
            url: urlSubject.eraseToAnyPublisher(),
            playPause: playStopButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.playPauseImage
            .sink { [playStopButton] in playStopButton.setImage($0, for: .normal) }
            .store(in: &cancelable)

        output.viewState
            .sink { [weak self] in self?.update(viewState: $0) }
            .store(in: &cancelable)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        cornerRadius = rounding.cornerRadius(view: self)
    }

    func play(url: URL?) {
        urlSubject.send(url)
    }

    func cancel() {
        play(url: nil)
    }

    private func update(viewState state: AVPlayerViewModel.LoadVideoState) {
        switch state {
        case .loading:
            playStopButton.isHidden = true
            loadingIndicator.startAnimating()
        case .done, .failure:
            loadingIndicator.stopAnimating()
            playStopButton.isHidden = false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AVPlayerView {

    enum PlayButtonPositioning {
        case center
        case bottomRight
    }
}
