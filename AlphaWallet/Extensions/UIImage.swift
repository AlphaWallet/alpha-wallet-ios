// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

extension UIImage {
    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }

    var withMonoEffect: UIImage? {
        let context = CIContext()
        guard let filter = CIFilter(name: "CIPhotoEffectMono") else { return nil }
        filter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        guard let output = filter.outputImage, let image = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image, scale: scale, orientation: imageOrientation)
    }
}
