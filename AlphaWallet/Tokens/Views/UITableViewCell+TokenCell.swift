// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

extension UITableViewCell {
    typealias TokenCellSeparators = (topBar: UIView, topLine: UIView, bottomLine: UIView)

    static func createTokenCellSeparators(height: CGFloat, separatorHeight: CGFloat) -> TokenCellSeparators {
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false

        let topLine = UIView()
        topLine.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(topLine)

        NSLayoutConstraint.activate([
            topLine.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: separatorHeight),
            topLine.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),

            topBar.heightAnchor.constraint(equalToConstant: height + separatorHeight),
        ])

        let bottomLine = UIView()
        bottomLine.translatesAutoresizingMaskIntoConstraints = false

        return (topBar: topBar, topLine: topLine, bottomLine: bottomLine)
    }
}
