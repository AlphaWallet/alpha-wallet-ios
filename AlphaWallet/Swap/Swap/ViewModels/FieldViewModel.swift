//
//  FieldViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine

class FieldViewModel {
    let isHidden: AnyPublisher<Bool, Never>
    let valueAttributedString: AnyPublisher<NSAttributedString?, Never>
    var backgroundColor: UIColor = R.color.alabaster()!
    var titleAttributedString: NSAttributedString {
        NSAttributedString(string: title, attributes: [
            .font: Fonts.regular(size: 15),
            .foregroundColor: R.color.dove()!
        ])
    }

    private let title: String

    init(title: String, value: AnyPublisher<String, Never>, isHidden: AnyPublisher<Bool, Never> = .just(false)) {
        self.title = title
        self.valueAttributedString = value.map {
            return NSAttributedString(string: $0.replacingOccurrences(of: "\0", with: ""), attributes: [
                .font: Fonts.regular(size: 17),
                .foregroundColor: Colors.black
            ])
        }.receive(on: RunLoop.main)
        .eraseToAnyPublisher()
        self.isHidden = isHidden
    }
}
