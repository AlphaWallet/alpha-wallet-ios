// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol DateEntryFieldDelegate: class {
    func didTap(in dateEntryField: DateEntryField)
}

class DateEntryField: UIControl {
    private let leftButton = UIButton(type: .custom)

    var value = Date() {
        didSet {
            displayDateString()
        }
    }
    weak var delegate: DateEntryFieldDelegate?

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        leftButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        displayDateString()

        let rightView = makeRightView()
        let stackView = [.spacerWidth(22), leftButton, rightView].asStackView(alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
        ])

        configure()
    }

    private func configure() {
        cornerRadius = DataEntry.Metric.cornerRadius

        layer.borderColor = DataEntry.Color.border.cgColor
        layer.borderWidth = DataEntry.Metric.borderThickness

        leftButton.setTitleColor(DataEntry.Color.text, for: .normal)
        leftButton.titleLabel?.font = DataEntry.Font.text
    }

    private func makeRightView() -> UIView {
        let rightButton = UIButton(type: .system)
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        rightButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        rightButton.imageView?.contentMode = .scaleAspectFit
        rightButton.setImage(R.image.calendar()?.withRenderingMode(.alwaysTemplate), for: .normal)
        rightButton.imageView?.tintColor = DataEntry.Color.icon
        //Needed for some reason to get imageView to use tintColor correctly
        rightButton.tintColor = DataEntry.Color.icon
        rightButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        let rightView = [rightButton].asStackView(distribution: .equalSpacing, spacing: 1)
        rightView.translatesAutoresizingMaskIntoConstraints = false

        return rightView
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func closeKeyboard() {
        delegate?.didTap(in: self)
    }

    @objc func buttonTapped() {
        delegate?.didTap(in: self)
    }

    private func displayDateString() {
        let dateString = value.format("dd MMM yyyy")
        leftButton.setTitle(dateString, for: .normal)
    }
}
