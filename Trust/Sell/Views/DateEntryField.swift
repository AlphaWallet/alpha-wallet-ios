// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol DateEntryFieldDelegate: class {
    func didTap(in dateEntryField: DateEntryField)
}

class DateEntryField: UIControl {
    var leftButton = UIButton(type: .custom)
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
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        configure()
    }

    private func configure() {
        layer.borderColor = Colors.appBackground.cgColor
        layer.borderWidth = 1

        leftButton.setTitleColor(Colors.appBackground, for: .normal)
        leftButton.titleLabel?.font = Fonts.bold(size: ScreenChecker().isNarrowScreen() ? 12: 18)
    }

    private func makeRightView() -> UIView {
        let rightButton = UIButton(type: .system)
        rightButton.translatesAutoresizingMaskIntoConstraints = false
        rightButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        rightButton.imageView?.contentMode = .scaleAspectFit
        rightButton.setImage(R.image.calendar(), for: .normal)
        rightButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        let rightView = [rightButton].asStackView(distribution: .equalSpacing, spacing: 1)
        rightView.translatesAutoresizingMaskIntoConstraints = false

        return rightView
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeToolbarWithDoneButton() -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closeKeyboard))

        toolbar.items = [flexSpace, done]
        toolbar.sizeToFit()

        return toolbar
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
