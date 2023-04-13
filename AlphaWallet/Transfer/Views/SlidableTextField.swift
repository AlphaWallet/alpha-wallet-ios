//
//  SlidableTextField.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit
import AlphaWalletFoundation
import Combine

protocol SlidableTextFieldDelegate: AnyObject {
    func shouldReturn(in textField: SlidableTextField) -> Bool
    func doneButtonTapped(for textField: SlidableTextField)
    func nextButtonTapped(for textField: SlidableTextField)
}

class SlidableTextField: UIView {

    private static let textFieldInsets: UIEdgeInsets = {
        let sideInset: CGFloat = ScreenChecker.size(big: 20, medium: 20, small: 16)
        return .init(top: 0, left: sideInset, bottom: 16, right: sideInset)
    }()

    private lazy var slider: UISlider = {
        let slider = UISlider(frame: .zero)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.isUserInteractionEnabled = true

        return slider
    }()

    lazy var textField: TextField = {
        let textField = TextField.buildTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self

        return textField
    }()
    private let textSubject = PassthroughSubject<Double, Never>()
    private var cancellable = Set<AnyCancellable>()

    var returnKeyType: UIReturnKeyType {
        get { return textField.returnKeyType }
        set { textField.returnKeyType = newValue }
    }

    var keyboardType: UIKeyboardType {
        get { return textField.keyboardType }
        set { textField.keyboardType = newValue }
    }

    var isSecureTextEntry: Bool {
        get { return textField.isSecureTextEntry }
        set { textField.isSecureTextEntry = newValue }
    }

    var status: TextField.TextFieldErrorState {
        get { return textField.status }
        set { textField.status = newValue }
    }

    weak var delegate: SlidableTextFieldDelegate?
    private let viewModel: SlidableTextFieldViewModel

    init(viewModel: SlidableTextFieldViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        let spacing: CGFloat = ScreenChecker().isNarrowScreen ? 8 : 16
        let row0 = [slider, textField].asStackView(axis: .horizontal, spacing: spacing)
        let row1 = textField.statusLabel
        let stackView = [
            row0,
            row1
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            textField.widthAnchor.constraint(equalToConstant: 100),
            stackView.anchorsConstraint(to: self, edgeInsets: SlidableTextField.textFieldInsets)
        ])
        translatesAutoresizingMaskIntoConstraints = false

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: SlidableTextFieldViewModel) {
        let value = slider.publisher(forEvent: .valueChanged)
            .compactMap { [weak slider] _ in slider?.value }
            .map { roundf($0) }

        let input = SlidableTextFieldViewModelInput(
            sliderChanged: value.eraseToAnyPublisher(),
            textChanged: textSubject.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.sliderViewState
            .sink { [weak slider] viewState in
                slider?.maximumValue = viewState.range.upperBound
                slider?.minimumValue = viewState.range.lowerBound
                slider?.setValue(viewState.value, animated: false)
            }.store(in: &cancellable)

        output.status
            .assign(to: \.status, on: textField, ownership: .weak)
            .store(in: &cancellable)

        output.text
            .assign(to: \.value, on: textField, ownership: .weak)
            .store(in: &cancellable)

        value
            .assign(to: \.value, on: slider, ownership: .weak)
            .store(in: &cancellable)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @discardableResult override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }
}

extension SlidableTextField: TextFieldDelegate {

    func shouldReturn(in textField: TextField) -> Bool {
        return delegate?.shouldReturn(in: self) ?? true
    }

    func doneButtonTapped(for textField: TextField) {
        delegate?.doneButtonTapped(for: self)
    }

    func nextButtonTapped(for textField: TextField) {
        delegate?.nextButtonTapped(for: self)
    }

    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        let convertedNSString = textField.value as NSString
        let newString: String = convertedNSString.replacingCharacters(in: range, with: string)
        if newString.isEmpty {
            return true
        } else {

            guard let value = viewModel.convertToDouble(string: newString) else { return false }
            textSubject.send(value)
            return true
        }
    }
}
