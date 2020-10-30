//
//  TransactionConfirmationHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.07.2020.
//

import UIKit

protocol TransactionConfirmationHeaderViewDelegate: class {
    func headerView(_ header: TransactionConfirmationHeaderView, openStateChanged section: Int)
}

class TransactionConfirmationHeaderView: UIView {

    struct Configuration {
        var isOpened: Bool = false
        let section: Int
        var shouldHideChevron: Bool = true
    }

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        return label
    }()

    private lazy var chevronView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chevronImageView)

        return view
    }()
    
    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = R.color.black()
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    lazy var trailingStackView: UIStackView = {
        return [].asStackView(axis: .horizontal)
    }()

    lazy var childrenStackView: UIStackView = {
        return [].asStackView(axis: .vertical)
    }()

    private var isSelectedObservation: NSKeyValueObservation!
    private var viewModel: TransactionConfirmationHeaderViewModel

    weak var delegate: TransactionConfirmationHeaderViewDelegate?

    init(viewModel: TransactionConfirmationHeaderViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let separatorLine = UIView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = R.color.mercury()

        let v2 = [titleLabel, detailsLabel].asStackView(axis: .vertical, alignment: .leading)
        v2.translatesAutoresizingMaskIntoConstraints = false

        let v1 = UIView()
        v1.translatesAutoresizingMaskIntoConstraints = false
        v1.addSubview(placeholderLabel)
        v1.addSubview(v2)

        let row0 = [
            .spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16),
            v1,
            trailingStackView,
            chevronView,
            .spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16)
        ].asStackView(axis: .horizontal, alignment: .top)

        let headerViews = [
            separatorLine,
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20),
            row0,
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20)
        ]

        for view in headerViews {
            view.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
            view.addGestureRecognizer(tap)
        }

        let stackView = (headerViews + [childrenStackView]).asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            trailingStackView.heightAnchor.constraint(equalTo: row0.heightAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: v1.topAnchor, constant: 5),
            placeholderLabel.leadingAnchor.constraint(equalTo: v1.leadingAnchor),
            placeholderLabel.widthAnchor.constraint(equalToConstant: 60),

            titleLabel.centerYAnchor.constraint(equalTo: placeholderLabel.centerYAnchor),

            v2.leadingAnchor.constraint(equalTo: placeholderLabel.trailingAnchor, constant: ScreenChecker().isNarrowScreen ? 8 : 16),
            v2.trailingAnchor.constraint(equalTo: v1.trailingAnchor),
            v2.topAnchor.constraint(lessThanOrEqualTo: placeholderLabel.topAnchor),
            v2.bottomAnchor.constraint(equalTo: v1.bottomAnchor),

            separatorLine.heightAnchor.constraint(equalToConstant: 1),

            chevronImageView.centerYAnchor.constraint(equalTo: placeholderLabel.centerYAnchor),
            chevronImageView.bottomAnchor.constraint(equalTo: chevronView.bottomAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: chevronView.trailingAnchor),
            chevronImageView.leadingAnchor.constraint(equalTo: chevronView.leadingAnchor),

            stackView.anchorsConstraint(to: self)
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configure(viewModel: TransactionConfirmationHeaderViewModel) {
        backgroundColor = viewModel.backgroundColor

        chevronView.isHidden = viewModel.configuration.shouldHideChevron

        chevronImageView.image = viewModel.chevronImage
        titleLabel.alpha = viewModel.titleAlpha

        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.isHidden = titleLabel.attributedText == nil

        placeholderLabel.attributedText = viewModel.placeholderAttributedString
        placeholderLabel.isHidden = placeholderLabel.attributedText == nil

        detailsLabel.attributedText = viewModel.detailsAttributedString
        detailsLabel.isHidden = detailsLabel.attributedText == nil
    }

    @objc private func didTap(_ sender: UITapGestureRecognizer) {
        viewModel.configuration.isOpened.toggle()

        chevronImageView.image = viewModel.chevronImage
        titleLabel.alpha = viewModel.titleAlpha

        delegate?.headerView(self, openStateChanged: viewModel.configuration.section)
    }

    func expand() {
        for view in childrenStackView.arrangedSubviews {
            view.isHidden = false
        }
    }

    func collapse() {
        for view in childrenStackView.arrangedSubviews {
            view.isHidden = true
        }
    }
}

extension TransactionConfirmationHeaderView {

    func setEditButton(section: Int, _ target: AnyObject, selector: Selector) {
        let label = UILabel()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        label.attributedText = NSAttributedString(string: "Edit", attributes: [
            .font: Fonts.bold(size: 15) as Any,
            .foregroundColor: R.color.azure() as Any,
            .paragraphStyle: paragraph
        ])
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false

        let tap = UITapGestureRecognizer(target: target, action: selector)
        label.addGestureRecognizer(tap)

        let wrapper = UIView()
        wrapper.addSubview(label)

        trailingStackView.addArrangedSubview(wrapper)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            label.widthAnchor.constraint(equalToConstant: 50)
        ])
    }
}
