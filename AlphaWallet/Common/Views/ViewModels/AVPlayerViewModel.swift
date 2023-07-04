//
//  AVPlayerViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.02.2023.
//

import UIKit
import AVKit
import Combine
import AlphaWalletFoundation

extension AVPlayer.TimeControlStatus {
    var playButtonImage: UIImage? {
        switch self {
        case .paused:
            return R.image.playButton()?.withRenderingMode(.alwaysTemplate)
        case .waitingToPlayAtSpecifiedRate:
            return R.image.pauseButton()?.withRenderingMode(.alwaysTemplate)
        case .playing:
            return R.image.pauseButton()?.withRenderingMode(.alwaysTemplate)
        @unknown default:
            return nil
        }
    }
}

struct AVPlayerViewModelInput {
    let url: AnyPublisher<URL?, Never>
    let playPause: AnyPublisher<Void, Never>
}

struct AVPlayerViewModelOutput {
    let playPauseImage: AnyPublisher<UIImage?, Never>
    let viewState: AnyPublisher<AVPlayerViewModel.LoadVideoState, Never>
}

class AVPlayerViewModel {
    private var cancelable = Set<AnyCancellable>()
    private let reachability: ReachabilityManagerProtocol
    private (set) lazy var player: AVPlayer = {
        let player = AVPlayer()
        player.actionAtItemEnd = .none
        player.volume = 0
        player.automaticallyWaitsToMinimizeStalling = false

        return player
    }()
    private let viewStateSubject = PassthroughSubject<AVPlayerViewModel.LoadVideoState, Never>()

    var viewState: AnyPublisher<AVPlayerViewModel.LoadVideoState, Never> {
        viewStateSubject.eraseToAnyPublisher()
    }

    init(reachability: ReachabilityManagerProtocol) {
        self.reachability = reachability
    }

    func transform(input: AVPlayerViewModelInput) -> AVPlayerViewModelOutput {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [player] _ in player.seek(to: CMTime.zero) }
            .store(in: &cancelable)

        input.playPause
            .filter { [player] _ in player.currentItem != nil }
            .sink { [player] _ in
                if player.timeControlStatus == AVPlayer.TimeControlStatus.playing {
                    player.pause()
                } else if player.timeControlStatus == AVPlayer.TimeControlStatus.paused {
                    player.play()
                } else {
                    //no-op
                }
            }.store(in: &cancelable)

        let playButtonImage = player.publisher(for: \.timeControlStatus)
            .map { $0.playButtonImage }
            .eraseToAnyPublisher()

        let viewStateSubject = PassthroughSubject<AVPlayerViewModel.LoadVideoState, Never>()

        input.url
            .removeDuplicates()
            .flatMapLatest { [player, weak self] url -> AnyPublisher<Void, Never> in
                guard let strongSelf = self else { return .empty() }

                guard let url = url else {
                    viewStateSubject.send(.failure(.emptyUrl))

                    player.replaceCurrentItem(with: nil)
                    return .just(())
                }

                return strongSelf.loadVideo(url: url)
                    .handleEvents(receiveOutput: { state in
                        switch state {
                        case .loading:
                            viewStateSubject.send(.loading)
                        case .loaded(let item, let isVideo):
                            let mediaType: MediaType = isVideo ? .video : .audio
                            viewStateSubject.send(.done(mediaType))

                            player.replaceCurrentItem(with: item)
                        }
                    }).mapToVoid()
                    .catch { e -> AnyPublisher<Void, Never> in
                        viewStateSubject.send(.failure(.assetFailure(e)))

                        return .just(())
                    }.eraseToAnyPublisher()
            }.sink(receiveValue: { _ in })
            .store(in: &cancelable)

        return .init(
            playPauseImage: playButtonImage,
            viewState: viewStateSubject.eraseToAnyPublisher())
    }

    private func loadVideo(url: URL) -> AnyPublisher<AVURLAsset.AVAssetLoadingState, AVURLAsset.AVAssetError> {
        //TODO: might be needed to verify `networkBecomeReachablePublisher` it doesn't work as expected
        return reachability.networkBecomeReachablePublisher
            .setFailureType(to: AVURLAsset.AVAssetError.self)
            .flatMapLatest { _ in AVURLAsset(url: url).loadValuesAsync() }
            .retry(3)
            .eraseToAnyPublisher()
    }
}

extension AVPlayerViewModel {

    enum MediaType {
        case video
        case audio
    }

    enum PlayerError: Error {
        case emptyUrl
        case assetFailure(AVURLAsset.AVAssetError)
    }

    enum LoadVideoState {
        case loading
        case done(MediaType)
        case failure(PlayerError)
    }
}

extension AVURLAsset {

    enum ImageGeneratorError: Error {
        case `internal`(Error)
    }

    private func _generator(size: CGSize) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: self)
        generator.maximumSize = size
        generator.appliesPreferredTrackTransform = true
        return generator
    }

    enum AVAssetError: Error {
        case general(Error)
        case unknown
        case cancelled
    }

    enum AVAssetLoadingState: Equatable {
        case loading
        /// isVideoAvailable == false - suppose is audio, might be needed to update, good for now
        case loaded(AVPlayerItem, isVideoAvailable: Bool)
    }

    func loadValuesAsync() -> AnyPublisher<AVAssetLoadingState, AVAssetError> {
        let asset = self
        let playableKey = "playable"
        let durationKey = "duration"

        return AnyPublisher<AVAssetLoadingState, AVAssetError>.create { seal in
            seal.send(.loading)

            asset.loadValuesAsynchronously(forKeys: [playableKey, durationKey]) {
                DispatchQueue.main.async {
                    var error: NSError?
                    let status = asset.statusOfValue(forKey: playableKey, error: &error)

                    switch status {
                    case .loading:
                        seal.send(.loading)
                    case .loaded:
                        let playerItem = AVPlayerItem(asset: asset)
                        if let e = playerItem.error {
                            seal.send(completion: .failure(AVAssetError.general(e)))
                        } else {
                            seal.send(.loaded(playerItem, isVideoAvailable: asset.isVideoAvailable))
                            seal.send(completion: .finished)
                        }
                    case .failed:
                        let error = error.flatMap { AVAssetError.general($0) } ?? .unknown

                        seal.send(completion: .failure(error))
                    case .cancelled:
                        seal.send(completion: .failure(.cancelled))
                    case .unknown:
                        seal.send(completion: .failure(.unknown))
                    @unknown default:
                        seal.send(completion: .failure(.unknown))
                    }
                }
            }

            return AnyCancellable {
                asset.cancelLoading()
            }
        }.removeDuplicates()
        .eraseToAnyPublisher()
    }

    func extractUIImageAsync(size: CGSize) -> AnyPublisher<UIImage?, ImageGeneratorError> {
        let generator = _generator(size: size)
        return AnyPublisher<UIImage?, ImageGeneratorError>.create { observer in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: .zero)]) { (_, image, _, _, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        observer.send(completion: .failure(.internal(error)))
                        return
                    }
                    observer.send(image.map(UIImage.init(cgImage:)))
                    observer.send(completion: .finished)
                }
            }

            return AnyCancellable {
                generator.cancelAllCGImageGeneration()
            }
        }
    }
}

extension AVAsset {
    var isAudioAvailable: Bool {
        return !tracks.filter { $0.mediaType == .audio }.isEmpty
    }

    var isVideoAvailable: Bool {
        return !tracks.filter { $0.mediaType == .video }.isEmpty
    }
}
