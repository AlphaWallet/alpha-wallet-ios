// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TimeEntryFieldDelegate: class {
    func didTap(in timeEntryField: TimeEntryField)
}

class TimeEntryField: UIControl {
    private let leftButton = UIButton(type: .custom)

    var value = Date() {
        didSet {
            displayTimeString()
        }
    }
    weak var delegate: TimeEntryFieldDelegate?

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        leftButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        displayTimeString()

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
        rightButton.setImage(R.image.time()?.withRenderingMode(.alwaysTemplate), for: .normal)
        //Needed for some reason to get imageView to use tintColor correctly
        rightButton.imageView?.tintColor = DataEntry.Color.icon
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

    private func displayTimeString() {
        leftButton.setTitle(value.format("hh:mm"), for: .normal)
    }
}
