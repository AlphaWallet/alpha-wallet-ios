// Copyright SIX DAY LLC. All rights reserved.
import UIKit

enum WellDoneAction {
    case other
}

protocol WellDoneViewControllerDelegate: AnyObject {
    func didPress(action: WellDoneAction, sender: UIView, in viewController: WellDoneViewController)
}

class WellDoneViewController: UIViewController {
    weak var delegate: WellDoneViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        let imageView = UIImageView(image: R.image.mascot_happy())
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = R.string.localizable.welldoneDescriptionLabelText()
        descriptionLabel.font = Label.Font.text
        descriptionLabel.textColor = Configuration.Color.Semantic.defaultForegroundText
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center

        let otherButton = Button(size: .normal, style: .solid)
        otherButton.translatesAutoresizingMaskIntoConstraints = false
        otherButton.setTitle(R.string.localizable.welldoneShareLabelText(), for: .normal)
        otherButton.addTarget(self, action: #selector(other(_:)), for: .touchUpInside)

        let stackView = [
            imageView,
            //titleLabel,
            descriptionLabel,
            .spacer(height: 10),
            .spacer(),
            otherButton,
        ].asStackView(axis: .vertical, spacing: 10, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.backgroundColor = Configuration.Color.Semantic.dialogBackground
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),

            otherButton.widthAnchor.constraint(equalToConstant: 240),
        ])
    }

    @objc private func other(_ sender: UIView) {
        delegate?.didPress(action: .other, sender: sender, in: self)
    }
}
