// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Eureka

open class SliderTextFieldCell: Cell<Float>, CellType, UITextFieldDelegate {

    private var awakeFromNibCalled = false

    @IBOutlet open weak var titleLabel: UILabel!
    @IBOutlet open weak var valueLabel: UILabel!
    @IBOutlet open weak var slider: UISlider!

    lazy var textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        textField.keyboardType = .numberPad
        textField.delegate = self
        textField.returnKeyType = .done
        textField.textAlignment = .right
        textField.layer.cornerRadius = 5
        textField.layer.borderColor = Colors.lightGray.cgColor
        textField.layer.borderWidth = 0.3
        textField.rightViewMode = .always
        textField.rightView = UIView.spacerWidth(5)
        return textField
    }()

    open var formatter: NumberFormatter?

    public required init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)

        // swiftlint:disable all
        NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
            guard let me = self else { return }
            if me.shouldShowTitle {
                me.titleLabel = me.textLabel
                me.valueLabel = me.detailTextLabel
                me.addConstraints()
            }
        }
        // swiftlint:enable all
    }

    deinit {
        guard !awakeFromNibCalled else { return }
        NotificationCenter.default.removeObserver(self, name: UIContentSizeCategory.didChangeNotification, object: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        awakeFromNibCalled = true
    }

    open override func setup() {
        super.setup()
        if !awakeFromNibCalled {
            // title
            let title = textLabel
            textLabel?.translatesAutoresizingMaskIntoConstraints = false
            textLabel?.setContentHuggingPriority(UILayoutPriority(500), for: .horizontal)
            titleLabel = title

//            let value = detailTextLabel
//            value?.translatesAutoresizingMaskIntoConstraints = false
//            value?.setContentHuggingPriority(UILayoutPriority(500), for: .horizontal)
//            valueLabel = value
            detailTextLabel?.isHidden = true

            let slider = UISlider()
            slider.translatesAutoresizingMaskIntoConstraints = false
            slider.setContentHuggingPriority(UILayoutPriority(500), for: .horizontal)
            self.slider = slider

            if shouldShowTitle {
                contentView.addSubview(titleLabel)
                //contentView.addSubview(valueLabel!)
                contentView.addSubview(textField)
            }
            contentView.addSubview(slider)
            addConstraints()
        }

        textField.leftView = .spacerWidth(16)
        textField.leftViewMode = .always
        textField.rightView = .spacerWidth(16)
        textField.rightViewMode = .always
        textField.font = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 10: 13)
        textField.borderStyle = .none
        textField.backgroundColor = .white
        textField.layer.borderWidth = DataEntry.Metric.borderThickness
        textField.backgroundColor = DataEntry.Color.searchTextFieldBackground
        textField.layer.borderColor = UIColor.clear.cgColor
        textField.cornerRadius = DataEntry.Metric.cornerRadius

        selectionStyle = .none
        slider.minimumValue = sliderRow.minimumValue
        slider.maximumValue = sliderRow.maximumValue
        slider.addTarget(self, action: #selector(SliderTextFieldCell.valueChanged), for: .valueChanged)
    }

    open override func update() {
        super.update()
        titleLabel.text = row.title
        //valueLabel.text = row.displayValueFor?(row.value)
        //valueLabel.isHidden = !shouldShowTitle && !awakeFromNibCalled
        titleLabel.isHidden = textField.isHidden
        slider.value = row.value ?? 0.0
        slider.isEnabled = !row.isDisabled
        textField.text = row.displayValueFor?(row.value)
    }

    func addConstraints() {
        guard !awakeFromNibCalled else { return }

        textField.heightAnchor.constraint(equalToConstant: 30).isActive = true
        textField.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let views: [String: Any] = ["titleLabel": titleLabel, "textField": textField, "slider": slider]
        let metrics = ["vPadding": 12, "spacing": 12.0]
        if shouldShowTitle {
            contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[titleLabel]-[textField]-|", options: .alignAllLastBaseline, metrics: metrics, views: views))
            contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-vPadding-[titleLabel]-spacing-[slider]-vPadding-|", options: .alignAllLeft, metrics: metrics, views: views))
        } else {
            contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-vPadding-[slider]-vPadding-|", options: .alignAllLeft, metrics: metrics, views: views))
        }

        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[slider]-|", options: .alignAllLastBaseline, metrics: metrics, views: views))
    }

    @objc func valueChanged() {
        let roundedValue: Float
        let steps = Float(sliderRow.steps)
        if steps > 0 {
            //Split out computation for numerator and denominator to speed up build time. 2.9s -> <100ms, as of Xcode 11.7
            let stepValueNumerator = (slider.value - slider.minimumValue)
            let stepValueDenominator = (slider.maximumValue - slider.minimumValue) * steps
            let stepValue = round(stepValueNumerator / stepValueDenominator)

            let stepAmount = (slider.maximumValue - slider.minimumValue) / steps
            roundedValue = stepValue * stepAmount + slider.minimumValue
        } else {
            roundedValue = slider.value
        }
        row.value = roundedValue
        row.updateCell()

        textField.text = "\(Int(roundedValue))"
    }

    var shouldShowTitle: Bool {
        return row?.title?.isEmpty == false
    }

    private var sliderRow: SliderTextFieldRow {
        return row as! SliderTextFieldRow
    }

    @objc func textFieldDidChange(textField: UITextField) {
        let value = Float(textField.text ?? "0") ?? sliderRow.minimumValue
        let minValue = min(value, sliderRow.minimumValue)
        let maxValue = max(value, sliderRow.maximumValue)

        sliderRow.minimumValue = minValue
        sliderRow.maximumValue = maxValue

        slider.maximumValue = minValue
        slider.maximumValue = maxValue

        row.value = value
        slider.value = value
    }

    open func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.clear.cgColor
        textField.backgroundColor = DataEntry.Color.searchTextFieldBackground

        textField.dropShadow(color: .clear, radius: DataEntry.Metric.shadowRadius)
    }

    open func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.backgroundColor = Colors.appWhite
        textField.layer.borderColor = DataEntry.Color.textFieldShadowWhileEditing.cgColor

        textField.dropShadow(color: DataEntry.Color.textFieldShadowWhileEditing, radius: DataEntry.Metric.shadowRadius)
    }

    @objc public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }

    open override func cellCanBecomeFirstResponder() -> Bool {
        return !row.isDisabled && textField.canBecomeFirstResponder == true
    }

    open override func cellBecomeFirstResponder(withDirection: Direction) -> Bool {
        return textField.becomeFirstResponder()
    }

    open override func cellResignFirstResponder() -> Bool {
        return textField.resignFirstResponder()
    }
}

/// A row that displays a UISlider. If there is a title set then the title and value will appear above the UISlider.
public final class SliderTextFieldRow: Row<SliderTextFieldCell>, RowType {

    public var minimumValue: Float = 0.0
    public var maximumValue: Float = 10.0
    public var steps: UInt = 20

    required public init(tag: String?) {
        super.init(tag: tag)
    }
}
