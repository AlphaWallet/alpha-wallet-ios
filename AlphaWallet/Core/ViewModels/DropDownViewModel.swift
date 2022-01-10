//
//  DropDownViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.08.2021.
//

import UIKit

protocol DropDownItemType: Equatable {
    var title: String { get }
}

struct DropDownViewModel<T: DropDownItemType> {
    let selectionItems: [T]
    var selected: SegmentedControl.Selection
    var placeholder: String = R.string.localizable.sortTokensSortBy("-")

    func placeholder(for selection: SegmentedControl.Selection) -> String {
        switch selection {
        case .unselected:
            return placeholder
        case .selected(let idx):
            return R.string.localizable.sortTokensSortBy(selectionItems[Int(idx)].title)
        }
    }

    init(selectionItems: [T], selected: T) {
        self.selectionItems = selectionItems
        self.selected = DropDownViewModel.elementSelection(of: selected, in: selectionItems)
    }

    func attributedString(item: T) -> NSAttributedString {
        return NSAttributedString(string: item.title, attributes: [
            .font: Fonts.regular(size: 23),
            .foregroundColor: Colors.sortByTextColor
        ])
    }

    static func elementSelection(of selected: T, in selectionItems: [T]) -> SegmentedControl.Selection {
        guard let index = selectionItems.firstIndex(where: { $0 == selected }) else {
            return .unselected
        }

        return .selected(UInt(index))
    }
}

extension SortTokensParam: DropDownItemType {
    var title: String {
        switch self {
        case .byField(let field, let direction):
            switch (field, direction) {
            case (.name, .ascending):
                return R.string.localizable.sortTokensParamNameAscending(preferredLanguages: Languages.preferred())
            case (.name, .descending):
                return R.string.localizable.sortTokensParamNameDescending(preferredLanguages: Languages.preferred())
            case (.value, .ascending):
                return R.string.localizable.sortTokensParamValueAscending(preferredLanguages: Languages.preferred())
            case (.value, .descending):
                return R.string.localizable.sortTokensParamValueDescending(preferredLanguages: Languages.preferred())
            }
        case .mostUsed:
            return R.string.localizable.sortTokensParamMostUsed(preferredLanguages: Languages.preferred())
        }
    }

}
