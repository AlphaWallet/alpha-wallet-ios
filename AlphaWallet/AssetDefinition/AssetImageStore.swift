// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Alamofire

//kkk need a singleton. Especially if we need to reduce disk reads to get images? Otherwise no
class AssetImageStore {
    enum Result {
        case cached
        case updated
        case unmodified
        case error
    }

    let contractAddress: String
    let imageType: AssetImageType

    private let cachesDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0])
    private let imageDirectoryName = "assetImages"
    private lazy var directory = cachesDirectory.appendingPathComponent(imageDirectoryName).appendingPathComponent(contractAddress.standardizedContractName)

    private var httpHeaders: HTTPHeaders = {
        guard let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return [:] }
        return [
            "X-Client-Name": Constants.repoClientName,
            "X-Client-Version": appVersion,
            "X-Platform-Name": Constants.repoPlatformName,
            "X-Platform-Version": UIDevice.current.systemVersion
        ]
    }()

    init(contract: String, imageType: AssetImageType) {
        contractAddress = contract.add0x.lowercased()
        self.imageType = imageType
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    subscript(id: String) -> String? {
        let path = filePath(forId: id)
        if FileManager.default.fileExists(atPath: path) {
            return path
        } else {
            return nil
        }
    }

    func fetchImage(forId id: String, completionHandler: ((Result) -> Void)? = nil) {
        //kkk read disk. Slow?
        if self[id] != nil {
            NSLog("xxx have asset image: \(id)")
            completionHandler?(.cached)
        }
        guard let urlString = XMLHandler(contract: contractAddress).getStaticImageURL(forId: id) else { return}
        guard let url = URL(string: urlString) else { return }
        NSLog("xxx kick start download for asset image: \(id)")
        //kkk when do we retry download even if cached? Otherwise we don't have a chance to see if it's changed. App launch? Or whenever we refresh the XML asset definition?
        Alamofire.request(
                url,
                method: .get,
                headers: httpHeadersWithLastModifiedTimestamp(forId: id)
        ).response { response in
            if response.response?.statusCode == 304 {
                completionHandler?(.unmodified)
                return
            }

            if let lastModifiedString = response.response?.allHeaderFields["Last-Modified"] as? String,
               let lastModifiedDateForDownloadedImage = httpHeaderLastModifiedDate(fromString: lastModifiedString),
               let lastModifiedDateForCachedImage = self.lastModifiedDateOfCachedImage(forId: id),
               lastModifiedDateForDownloadedImage < lastModifiedDateForCachedImage {
                completionHandler?(.unmodified)
                return
            }

            if let data = response.data, !data.isEmpty {
                //Server might not returning last modified date correctly, we compare the raw image data to not fire the wrong state, otherwise we might easily get into an infinite loop where we keep downloading and firing that the image is updated
                let fileURL = self.fileURL(forId: id)
                if let cachedImageData = try? Data(contentsOf: fileURL), cachedImageData == data {
                    completionHandler?(.unmodified)
                    return
                }

                do {
                    try data.write(to: fileURL)
                    self.uploadImageToServer(forContract: self.contractAddress, id: id)
                    completionHandler?(.updated)
                    //kkk subscribers
//                    self.subscribers.forEach { $0(contract) }
                } catch {
                    self.retrieveImageFromFallbackServer(forId: id, completionHandler: completionHandler)
                }
            } else {
                self.retrieveImageFromFallbackServer(forId: id, completionHandler: completionHandler)
            }
        }
    }

    private func retrieveImageFromFallbackServer(forId id: String, completionHandler: ((Result) -> Void)? = nil) {
        guard let fallBackURL = fallbackStaticImageURL(forId: id) else {
            completionHandler?(.error)
            return
        }
        Alamofire.request(
                fallBackURL,
                method: .get,
                headers: nil
        ).response { response in
            if let data = response.data, !data.isEmpty {
                do {
                    let fileURL = self.fileURL(forId: id)
                    try data.write(to: fileURL)
                    completionHandler?(.updated)
                } catch {
                    completionHandler?(.error)
                }
            } else {
                completionHandler?(.error)
            }
        }
    }

    private func fallbackStaticImageURL(forId id: String) -> URL? {
        //kkk form server URL. Constant prefix?
//        return URL(string: "https://img.alphawallet.io/\(contractAddress)/\(id).\(imageType)")
        return nil
    }

    private func uploadImageToServer(forContract: String, id: String) {
        //kkk upload image to server
    }

    private func filePath(forId id: String) -> String {
        return fileURL(forId: id).path
    }

    private func fileURL(forId id: String) -> URL {
        return directory.appendingPathComponent("\(id).\(imageType)")
    }

    private func httpHeadersWithLastModifiedTimestamp(forId id: String) -> HTTPHeaders {
        var result = httpHeaders
        if let lastModified = lastModifiedDateOfCachedImage(forId: id) {
            result["IF-Modified-Since"] = string(fromHTTPHeaderLastModifiedDate: lastModified)
            return result
        } else {
            return result
        }
    }

    private func lastModifiedDateOfCachedImage(forId id: String) -> Date? {
        let path = fileURL(forId: id)
        guard let lastModified = try? path.resourceValues(forKeys: [.contentModificationDateKey]) else { return nil }
        return lastModified.contentModificationDate as? Date
    }
}
