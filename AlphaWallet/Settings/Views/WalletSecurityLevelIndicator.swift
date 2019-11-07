// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

class WalletSecurityLevelIndicator: UIView {
    private let level: WalletSecurityLevel
    private let segmentImageView: UIImageView
    private let label = UILabel()

    init(level: WalletSecurityLevel) {
        self.level = level
        self.segmentImageView = .init(image: WalletSecurityLevelIndicator.convertLevelToImages(level))

        let rightMargin = CGFloat(10)

        super.init(frame: .init(x: 0, y: 0, width: 80 + rightMargin, height: 26))

        let stackView = [
            segmentImageView,
            UIView.spacer(height: 4),
            label,
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: 0, bottom: 0, right: rightMargin)),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        label.textAlignment = .center
        label.font = Fonts.regular(size: 11)
        label.textColor = Colors.settingsSubtitle
        label.text = WalletSecurityLevelIndicator.convertLevelToTitle(level)
    }

    private static func convertLevelToImages(_ level: WalletSecurityLevel) -> UIImage {
        switch level {
        case .notBackedUp:
            return R.image.wallet_security_red_bar()!
        case .backedUpButSecurityIsNotElevated:
            return R.image.wallet_security_orange_bar()!
        case .backedUpWithElevatedSecurity:
            return R.image.wallet_security_green_bar()!
        }
    }

    private static func convertLevelToTitle(_ level: WalletSecurityLevel) -> String {
        switch level {
        case .notBackedUp:
            return R.string.localizable.walletSecurityLevelRed()
        case .backedUpButSecurityIsNotElevated:
            return R.string.localizable.walletSecurityLevelOrange()
        case .backedUpWithElevatedSecurity:
            return R.string.localizable.walletSecurityLevelGreen()
        }
    }
}
