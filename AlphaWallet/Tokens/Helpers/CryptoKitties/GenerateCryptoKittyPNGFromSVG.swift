// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Macaw
import PromiseKit

class GenerateCryptoKittyPNGFromSVG {
    private let imageCache = ImageCache()
    private var promises = [URL: Promise<UIImage>]()

    func withDownloadedImage(fromURL url: URL?, forTokenId tokenId: String?) -> Promise<UIImage> {
        guard let tokenId = tokenId else {
            return Promise { $0.resolve(nil, GenerationError()) }
        }
        guard let url = url else {
            return Promise { $0.resolve(nil, GenerationError()) }
        }

        if let promise = promises[url] {
            return promise
        }

        if let image = cachedImage(forKittyId: tokenId) {
            return Promise { $0.resolve(image, nil) }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .returnCacheDataElseLoad
        let promise = Alamofire.request(request).responseData().then { data, response -> Promise<UIImage> in
            let imagePromise = self.generateImage(data: data)
            return imagePromise
        }.then { image -> Promise<UIImage> in
            self.cache(image: image, forKittyId: tokenId)
            return Promise { $0.resolve(image, nil) }
        }
        promises[url] = promise
        return promise
    }

    private func generateImage(data: Data) -> Promise<UIImage> {
        return Promise { seal in
            guard let string = String(data: data, encoding: .utf8), let node = try? SVGParser.parse(text: string), let group = node as? Group else {
                seal.resolve(nil, GenerationError())
                return
            }
            let widestWidthPossiblyNeeded = UIScreen.main.bounds.width
            let size = CGSize(width: widestWidthPossiblyNeeded, height: widestWidthPossiblyNeeded)
            let screenScale = UIScreen.main.scale
            DispatchQueue.global(qos: .userInitiated).async {
                UIGraphicsBeginImageContextWithOptions(size, false, screenScale)
                guard let graphicsContext = UIGraphicsGetCurrentContext() else {
                    UIGraphicsEndImageContext()
                    seal.resolve(nil, GenerationError())
                    return
                }
                graphicsContext.concatenate(LayoutHelper().getTransform(group, ContentLayout.of(contentMode: .scaleAspectFit), size.toMacaw()))
                let renderer = RenderUtils.createNodeRenderer(group)
                renderer.render(in: graphicsContext, force: false, opacity: group.opacity)
                guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                    UIGraphicsEndImageContext()
                    seal.resolve(nil, GenerationError())
                    return
                }
                UIGraphicsEndImageContext()
                seal.resolve(image, nil)
            }
        }
    }

    private func cryptoKittyImageKey(fromKittyId kittyId: String) -> String {
        return "cryptokitty-\(kittyId)"
    }

    private func cachedImage(forKittyId kittyId: String) -> UIImage? {
        return imageCache[cryptoKittyImageKey(fromKittyId: kittyId)]
    }

    private func cache(image: UIImage, forKittyId kittyId: String) {
        imageCache[cryptoKittyImageKey(fromKittyId: kittyId)] = image
    }

    private struct GenerationError: LocalizedError {
    }
}
