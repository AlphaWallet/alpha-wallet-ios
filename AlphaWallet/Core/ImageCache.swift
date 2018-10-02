// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

//TODO possible performance improvement if we cache in-memory?
class ImageCache {
    private static let defaultDirectoryName = "imageCache"

    private let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0])
    private let directoryName: String
    lazy var directory = documentsDirectory.appendingPathComponent(directoryName)

    init(directoryName: String = defaultDirectoryName) {
        self.directoryName = directoryName
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fullURL(for key: String) -> URL {
        return directory.appendingPathComponent(filename(fromKey: key))
    }

    private func filename(fromKey key: String) -> String {
        return "\(key).png"
    }

    subscript(key: String) -> UIImage? {
        get {
            let url = fullURL(for: key)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return ImageCache.image(fromData: data)
        }
        set(image) {
            guard let image = image else { return }
            let url = fullURL(for: key)
            let data = UIImagePNGRepresentation(image)
            try? data?.write(to: url)
        }
    }

    static func image(fromData data: Data) -> UIImage? {
        return UIImage(data: data, scale: UIScreen.main.scale)
    }
}
