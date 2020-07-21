// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

class CollectionViewLeftAlignedFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let originalAttributes = super.layoutAttributesForElements(in: rect) else { return nil }
        var updatedAttributes = originalAttributes
        for each in originalAttributes where each.representedElementKind == nil {
            guard let index = updatedAttributes.firstIndex(of: each) else { continue }
            layoutAttributesForItem(at: each.indexPath).flatMap { updatedAttributes[index] = $0 }
        }
        return updatedAttributes
    }
    // swiftlint:disable all
    //Force each item in every row, other than the first item in each row, to be place to the right of the previous item
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let currentItemAttributes = super.layoutAttributesForItem(at: indexPath) else { return nil }
        //First item in section is also first item in current row, so we can early return
        let isFirstItemInSection = indexPath.item == 0
        if isFirstItemInSection {
            currentItemAttributes.positionFrameX(x: sectionInset.left)
            return currentItemAttributes
        }

        guard let collectionView = collectionView else { return nil }
        guard let previousFrame = previousItemFrameOfItem(withIndexPath: indexPath) else { return currentItemAttributes }
        let previousFrameRightPoint = previousFrame.origin.x + previousFrame.width
        let currentFrame = currentItemAttributes.frame
        let collectionViewContentWidth = collectionView.frame.width - sectionInset.left - sectionInset.right
        let currentRowFrameInCollectionView = CGRect(x: sectionInset.left, y: currentFrame.origin.y, width: collectionViewContentWidth, height: currentFrame.size.height)
        let isFirstItemInRow = previousFrame.intersection(currentRowFrameInCollectionView).isEmpty

        if isFirstItemInRow {
            currentItemAttributes.positionFrameX(x: sectionInset.left)
            return currentItemAttributes
        }

        currentItemAttributes.positionFrameX(x: previousFrameRightPoint + minimumInteritemSpacing)
        return currentItemAttributes
    }
    // swiftlint:enable all

    private func previousItemFrameOfItem(withIndexPath indexPath: IndexPath) -> CGRect? {
        let previousIndexPath = IndexPath(item: indexPath.item - 1, section: indexPath.section)
        guard let previousAttributes = layoutAttributesForItem(at: previousIndexPath) else { return nil }
        let previousFrame = previousAttributes.frame
        return previousFrame
    }
}

fileprivate extension UICollectionViewLayoutAttributes {
    func positionFrameX(x: CGFloat) {
        var frame = self.frame
        frame.origin.x = x
        self.frame = frame
    }
}
