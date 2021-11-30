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

    var isEveryWordSelected: Bool {
        return selectedIndices.count == words.count
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

    func getSelectedSeedPhraseWord() -> [String] {
        var selectedWords = [String]()
        for (index, value) in words.enumerated() {
            if isWordSelected(atIndex: index) {
                selectedWords.append(value)
            }
        }
        return selectedWords
    }
}
