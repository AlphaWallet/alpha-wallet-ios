//
//  ImageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.03.2023.
//

import Foundation
import AlphaWalletFoundation
import Combine

class ImageView: UIImageView {
    private let subject: PassthroughSubject<ImagePublisher, Never> = .init()
    private var cancellable = Set<AnyCancellable>()

    var hideWhenImageIsNil: Bool = false

    init() {
        super.init(frame: .zero)
        bind()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        bind()
    }

    private func bind() {
        subject.flatMapLatest { $0 }
            .sink { [weak self] image in
                self?.image = image
                if self?.hideWhenImageIsNil ?? false {
                    self?.isHidden = self?.hideWhenImageIsNil ?? false
                }
            }.store(in: &cancellable)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(imageSource: ImagePublisher) {
        subject.send(imageSource)
    }
}
