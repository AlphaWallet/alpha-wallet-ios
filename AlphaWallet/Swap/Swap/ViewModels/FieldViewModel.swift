//
//  FieldViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

class FieldViewModel: ObservableObject {
    private let title: String
    var valueAttributedString: AnyPublisher<NSAttributedString?, Never>

    var backgroundColor: UIColor = R.color.alabaster()!

    var titleAttributedString: NSAttributedString {
        NSAttributedString(string: title, attributes: [
            .font: Fonts.regular(size: 15),
            .foregroundColor: R.color.dove()!
        ])
    }

    init(title: String, value: AnyPublisher<String, Never>) {
        self.title = title
        self.valueAttributedString = value.map {
            return NSAttributedString(string: $0, attributes: [
                .font: Fonts.regular(size: 17),
                .foregroundColor: Colors.black
            ])
        }.eraseToAnyPublisher()
    }
}
