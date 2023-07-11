//
//  ImageLoader.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.02.2023.
//

import UIKit
import Combine
import AVKit
import AlphaWalletCore
import AlphaWalletFoundation

protocol ContentCacheStorage: AnyObject {
    func value(for key: String) throws -> Data?
    func set(data: Data, for key: String) throws
}

protocol MediaContentDownloaderContentResponseInterceptor: AnyObject {
    func intercept(response: MediaContentDownloader.Content) -> MediaContentDownloader.LoadContentPublisher
}

fileprivate enum ImageCacheKey: CaseIterable {
    case raw
    case viewStillPreview

    static func cacheKey(for url: URL, prefix: ImageCacheKey) -> String {
        switch prefix {
        case .raw:
            return url.absoluteString
        case .viewStillPreview:
            return "video-preview-\(url.absoluteString)"
        }
    }
}

class GenerateVideoStillInterceptor: MediaContentDownloaderContentResponseInterceptor {
    private let cache: ContentCacheStorage

    var compressedImageSize: CGSize = CGSize(width: 400, height: 400)

    init(cache: ContentCacheStorage) {
        self.cache = cache
    }

    func intercept(response: MediaContentDownloader.Content) -> MediaContentDownloader.LoadContentPublisher {
        switch response {
        case .svg, .image:
            return .just(.done(response))
        case .video(let video):
            return AVURLAsset(url: video.url)
                .extractUIImageAsync(size: compressedImageSize)
                .map { [cache] preview -> Loadable<MediaContentDownloader.Content, MediaContentDownloader.NoError> in
                    guard let preview = preview, let pngData = preview.pngData() else { return .done(.video(video)) }

                    let video = MediaContentDownloader.Video(url: video.url, preview: preview)
                    try? cache.set(data: pngData, for: ImageCacheKey.cacheKey(for: video.url, prefix: .viewStillPreview))

                    return .done(.video(video))
                }.replaceError(with: .done(.video(video)))
                .setFailureType(to: MediaContentDownloader.ContentLoaderError.self)
                .eraseToAnyPublisher()
        }
    }
}

extension MediaContentDownloader {
    static func instance(reachability: ReachabilityManager) -> MediaContentDownloader {
        let mediaContentCache = KingfisherImageCacheStorage()

        return MediaContentDownloader(
            networking: MediaContentNetworkingImpl(),
            cache: mediaContentCache,
            contentResponseInterceptor: GenerateVideoStillInterceptor(cache: mediaContentCache),
            reachability: reachability)
    }
}

final class MediaContentDownloader {
    private let queue = DispatchQueue(label: "org.alphawallet.swift.imageLoader.processingQueue", qos: .utility)
    private var inFlightPublishers: [URLRequest: LoadContentPublisher] = [:]
    private let networking: MediaContentNetworking
    private let cache: ContentCacheStorage
    private let decoder: ContentDecoder
    private let contentResponseInterceptor: MediaContentDownloaderContentResponseInterceptor
    private let reachability: ReachabilityManagerProtocol /*use is later*/
    private let base64Decoder = Base64Decoder()

    init(networking: MediaContentNetworking,
         cache: ContentCacheStorage,
         decoder: ContentDecoder = ContentDecoder(),
         contentResponseInterceptor: MediaContentDownloaderContentResponseInterceptor,
         reachability: ReachabilityManagerProtocol) {

        self.reachability = reachability
        self.decoder = decoder
        self.contentResponseInterceptor = contentResponseInterceptor
        self.cache = cache
        self.networking = networking
    }

    //NOTE: we receive can receive base64 as url, so we need to decode it first and return right data
    //treat value from base64 as string to display in webview, might be needed to handle special mime types
    //or maybe its better to handle decoding base64 when return image for token, make special manager for it, not just static func like it is for now
    public func fetch(_ url: URL) -> LoadContentPublisher {
        if let data = base64Decoder.decode(string: url.absoluteString), data.mimeType != nil, let string = String(data: data.data, encoding: .utf8) {
            return .just(.done(.svg(string))).prepend(.loading).eraseToAnyPublisher()
        } else {
            let request = URLRequest(url: url)
            return fetch(request)
        }
    }

    public func fetch(_ urlRequest: URLRequest) -> LoadContentPublisher {
        return buildFetchPublisher(urlRequest)
            .prepend(.loading)
            .eraseToAnyPublisher()
    }

    private func loadFromCache(url: URL) -> LoadContentPublisher? {
        if let data = try? cache.value(for: ImageCacheKey.cacheKey(for: url, prefix: .raw)), let data = try? decoder.decode(data: data) {
            switch data {
            case .image, .svg:
                return .just(.done(data))
            case .video(let video):
                let preview = try? cache.value(for: ImageCacheKey.cacheKey(for: url, prefix: .viewStillPreview)).flatMap { UIImage(data: $0) }
                let video = Video(url: video.url, preview: preview)

                return .just(.done(.video(video)))
            }
        }
        return nil
    }

    private func buildFetchPublisher(_ urlRequest: URLRequest) -> LoadContentPublisher {
        guard let url = urlRequest.url else { return .fail(.invalidUrl) }

        if let publisher = loadFromCache(url: url) {
            return publisher
        }

        return Just(urlRequest)
            .receive(on: queue)
            .setFailureType(to: ContentLoaderError.self)
            .flatMap { [weak self, networking, queue, cache, decoder, contentResponseInterceptor] urlRequest -> LoadContentPublisher in
                if let publisher = self?.inFlightPublishers[urlRequest] {
                    return publisher
                } else {
                    let publisher = networking.dataTaskPublisher(urlRequest)
                        .receive(on: queue)
                        .mapError { ContentLoaderError.internal($0) }
                        .flatMap { response -> LoadContentPublisher in
                            do {
                                guard let url = response.response.url else {
                                    return .fail(ContentLoaderError.invalidData)
                                }

                                let value = try decoder.decode(response: response.response, data: response.data)
                                try cache.set(data: value.data, for: ImageCacheKey.cacheKey(for: url, prefix: .raw))

                                return contentResponseInterceptor.intercept(response: value.content)
                            } catch {
                                return .fail(ContentLoaderError.invalidData)
                            }
                        }.handleEvents(receiveCompletion: { _ in self?.inFlightPublishers[urlRequest] = nil })
                        .receive(on: RunLoop.main)
                        .share()
                        .eraseToAnyPublisher()

                    self?.inFlightPublishers[urlRequest] = publisher

                    return publisher
                }
            }.eraseToAnyPublisher()
    }
}

extension MediaContentDownloader {
    typealias LoadContentPublisher = AnyPublisher<Loadable<Content, NoError>, ContentLoaderError>

    struct NoError: Error {}

    enum ContentLoaderError: Error {
        case `internal`(Error)
        case invalidData
        case invalidUrl
    }

    enum Content {
        case image(UIImage)
        case svg(String)
        case video(Video)
    }

    struct Video {
        let url: URL
        let preview: UIImage?
    }

    private struct VideoUrl: Codable {
        let url: URL
    }

    struct ContentDecoder {
        typealias Response = (data: Data, content: Content)

        private func isValidResponse(statusCode: Int) -> Bool {
            return (200...299).contains(statusCode)
        }

        func decode(response: HTTPURLResponse, data: Data) throws -> Response {
            guard let url = response.url else { throw DecoderError.responseUrlNotFound }
            guard isValidResponse(statusCode: response.statusCode) else { throw DecoderError.invalidStatusCode(response.statusCode) }
            guard !data.isEmpty else { throw DecoderError.emptyDataResponse }

            return try decode(data: data, url: url)
        }

        enum DecoderError: Error {
            case decodeFailure(data: Data)
            case emptyDataResponse
            case responseUrlNotFound
            case invalidStatusCode(Int)
        }

        func decode(data: Data) throws -> Content {
            if let image = UIImage(data: data) {
                return .image(image)
            } else if let data = try? JSONDecoder().decode(VideoUrl.self, from: data) {
                return .video(.init(url: data.url, preview: nil))
            } else if let svg = String(data: data, encoding: .utf8) {
                return .svg(svg)
            } else {
                throw DecoderError.decodeFailure(data: data)
            }
        }

        private func decode(data: Data, url: URL) throws -> Response {
            if let image = UIImage(data: data) {
                return (data: data, .image(image))
            } else if let svg = String(data: data, encoding: .utf8) {
                return (data: data, .svg(svg))
            } else {
                let data = try JSONEncoder().encode(VideoUrl(url: url))
                return (data: data, .video(.init(url: url, preview: nil)))
            }
        }
    }
}
