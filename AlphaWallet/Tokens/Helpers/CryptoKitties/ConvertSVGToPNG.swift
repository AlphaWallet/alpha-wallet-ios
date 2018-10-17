// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Macaw
import PromiseKit

class ConvertSVGToPNG {
    private let imageCache = ImageCache()
    private var promises = [URL: Promise<UIImage>]()

    func withDownloadedImage(fromURL url: URL?, forTokenId tokenId: String?, withPrefix prefix: String) -> Promise<UIImage> {
        guard let tokenId = tokenId else {
            return Promise { $0.resolve(nil, GenerationError(errorDescription: "No tokenId")) }
        }
        guard let url = url else {
            return Promise { $0.resolve(nil, GenerationError(errorDescription: "No URL")) }
        }

        if let promise = promises[url] {
            return promise
        }

        if let image = cachedImage(forTokenId: tokenId, withPrefix: prefix) {
            return Promise { $0.resolve(image, nil) }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .returnCacheDataElseLoad
        //OK to retain strong self reference because we can still download the image and cache it for future sessions
        let promise = Alamofire.request(request).responseData().then { data, response -> Promise<UIImage> in
            let imageFileExtension = url.pathExtension.lowercased()
            if imageFileExtension.lowercased() == "svg" {
                let imagePromise = self.generateImage(data: data, fromURL: url, forTokenId: tokenId)
                return imagePromise
            } else {
                if let image = ImageCache.image(fromData: data) {
                    //TODO resize the image if it's drastically bigger than what we are using in the app
                    self.cache(image: image, forTokenId: tokenId, withPrefix: prefix)
                    return Promise { $0.resolve(image, nil) }
                } else {
                    return Promise { $0.resolve(nil, GenerationError(errorDescription: "Can't create image from data interpreted as PNG. URL: \(url) tokenId: \(tokenId)")) }
                }
            }
        }.then { image -> Promise<UIImage> in
            self.cache(image: image, forTokenId: tokenId, withPrefix: prefix)
            return Promise { $0.resolve(image, nil) }
        }
        promises[url] = promise
        return promise
    }

    private func generateImage(data: Data, fromURL url: URL, forTokenId tokenId: String) -> Promise<UIImage> {
        return Promise { seal in
            guard let string = String(data: data, encoding: .utf8), let node = try? SVGParser.parse(text: string), let group = node as? Group else {
                seal.resolve(nil, GenerationError(errorDescription: "Can't create string or node from data from URL: \(url) tokenId: \(tokenId)"))
                return
            }
            let widestWidthPossiblyNeeded = UIScreen.main.bounds.width
            let size = CGSize(width: widestWidthPossiblyNeeded, height: widestWidthPossiblyNeeded)
            let screenScale = UIScreen.main.scale
            DispatchQueue.global(qos: .userInitiated).async {
                UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
                guard let graphicsContext = UIGraphicsGetCurrentContext() else {
                    UIGraphicsEndImageContext()
                    seal.resolve(nil, GenerationError(errorDescription: "Can't retrieve new graphics context from URL: \(url) tokenId: \(tokenId)"))
                    return
                }
                graphicsContext.concatenate(LayoutHelper().getTransform(group, ContentLayout.of(contentMode: .scaleAspectFit), size.toMacaw()))
                let renderer = RenderUtils.createNodeRenderer(group)
                renderer.render(in: graphicsContext, force: false, opacity: group.opacity)
                guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                    UIGraphicsEndImageContext()
                    seal.resolve(nil, GenerationError(errorDescription: "Can't retrieve image from graphics context from URL: \(url) tokenId: \(tokenId)"))
                    return
                }
                UIGraphicsEndImageContext()
                seal.resolve(image, nil)
            }
        }
    }

    private func cachedImage(forTokenId tokenId: String, withPrefix prefix: String) -> UIImage? {
        return imageCache["\(prefix)-\(tokenId)"]
    }

    private func cache(image: UIImage, forTokenId tokenId: String, withPrefix prefix: String) {
        imageCache["\(prefix)-\(tokenId)"] = image
    }

    private struct GenerationError: LocalizedError {
        var errorDescription: String
    }
}
