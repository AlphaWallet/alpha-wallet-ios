// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SeedPhraseCollectionViewModel {
    private let words: [String]
    private var selectedIndices: [Int] = .init()

    let isSelectable: Bool
    let shouldShowSequenceNumber: Bool

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var seedPhraseWordCount: Int {
        return words.count
    }

    init(words: [String] = [], isSelectable: Bool = false, shouldShowSequenceNumber: Bool = false) {
        self.words = words
        self.isSelectable = isSelectable
        self.shouldShowSequenceNumber = shouldShowSequenceNumber
    }

    func seedPhraseWord(atIndex index: Int) -> String {
        return words[index]
    }

    func isWordSelected(atIndex index: Int) -> Bool {
        return selectedIndices.contains(index)
    }

    mutating func selectWord(atIndex index: Int) {
        guard isSelectable else { return }
        selectedIndices.append(index)
    }

    mutating func clearSelectedWords() {
        selectedIndices = []
    }
}
