// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Eureka

@IBDesignable public class FloatLabelTextField: UITextField {
    let animationDuration = 0.3
    var title = UILabel()

    // MARK: - Properties
    override public var accessibilityLabel: String! {
        get {
            if text?.isEmpty ?? true {
                return title.text
            } else {
                return text
            }
        }
        set {
            self.accessibilityLabel = newValue
        }
    }

    override public var placeholder: String? {
        didSet {
            title.text = placeholder
            title.sizeToFit()
        }
    }

    override public var attributedPlaceholder: NSAttributedString? {
        didSet {
            title.text = attributedPlaceholder?.string
            title.sizeToFit()
        }
    }

    var titleFont: UIFont = .systemFont(ofSize: 12.0) {
        didSet {
            title.font = titleFont
            title.sizeToFit()
        }
    }

    @IBInspectable var hintYPadding: CGFloat = 0.0

    @IBInspectable var titleYPadding: CGFloat = 0.0 {
        didSet {
            var r = title.frame
            r.origin.y = titleYPadding
            title.frame = r
        }
    }

    @IBInspectable var titleTextColour: UIColor = .gray {
        didSet {
            if !isFirstResponder {
                title.textColor = titleTextColour
            }
        }
    }

    @IBInspectable var titleActiveTextColour: UIColor! {
        didSet {
            if isFirstResponder {
                title.textColor = titleActiveTextColour
            }
        }
    }

    // MARK: - Init
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    // MARK: - Overrides
    override public func layoutSubviews() {
        super.layoutSubviews()
        setTitlePositionForTextAlignment()
        let isResp = isFirstResponder
        if isResp && !(text?.isEmpty ?? true) {
            title.textColor = titleActiveTextColour
        } else {
            title.textColor = titleTextColour
        }
        // Should we show or hide the title label?
        if text?.isEmpty ?? true {
            // Hide
            hideTitle(isResp)
        } else {
            // Show
            showTitle(isResp)
        }
    }

    override public func textRect(forBounds bounds: CGRect) -> CGRect {
        var r = super.textRect(forBounds: bounds)
        if !(text?.isEmpty ?? true) {
            var top = ceil(title.font.lineHeight + hintYPadding)
            top = min(top, maxTopInset())
            r = r.inset(by: .init(top: top, left: 0.0, bottom: 0.0, right: 0.0))
        }
        return r.integral
    }

    override public func editingRect(forBounds bounds: CGRect) -> CGRect {
        var r = super.editingRect(forBounds: bounds)
        if !(text?.isEmpty ?? true) {
            var top = ceil(title.font.lineHeight + hintYPadding)
            top = min(top, maxTopInset())
            r = r.inset(by: .init(top: top, left: 0.0, bottom: 0.0, right: 0.0))
        }
        return r.integral
    }

    override public func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        var r = super.clearButtonRect(forBounds: bounds)
        if !(text?.isEmpty ?? true) {
            var top = ceil(title.font.lineHeight + hintYPadding)
            top = min(top, maxTopInset())
            r = CGRect(x: r.origin.x, y: r.origin.y + (top * 0.5), width: r.size.width, height: r.size.height)
        }
        return r.integral
    }

    // MARK: - Public Methods

    // MARK: - Private Methods
    private func setup() {
        borderStyle = .none
        titleActiveTextColour = tintColor
        // Set up title label
        title.alpha = 0.0
        title.font = titleFont
        title.textColor = titleTextColour
        if let str = placeholder?.nilIfEmpty {
            title.text = str
            title.sizeToFit()
        }
        addSubview(title)
    }

    private func maxTopInset() -> CGFloat {
        //Split out computation to speed up build time. 300ms -> <50ms, as of Xcode 11.7
        let value: CGFloat = bounds.size.height - (font?.lineHeight ?? 0) - 4.0
        return max(0, floor(value))

    }

    private func setTitlePositionForTextAlignment() {
        let r = textRect(forBounds: bounds)
        var x = r.origin.x
        if textAlignment == .center {
            x = r.origin.x + (r.size.width * 0.5) - title.frame.size.width
        } else if textAlignment == .right {
            x = r.origin.x + r.size.width - title.frame.size.width
        }
        title.frame = CGRect(x: x, y: title.frame.origin.y, width: title.frame.size.width, height: title.frame.size.height)
    }

    private func showTitle(_ animated: Bool) {
        let dur = animated ? animationDuration : 0
        UIView.animate(withDuration: dur, delay: 0, options: UIView.AnimationOptions.beginFromCurrentState.union(.curveEaseOut), animations: { [weak self] in
            guard let strongSelf = self else { return }
            // Animation
            strongSelf.title.alpha = 1.0
            var r = strongSelf.title.frame
            r.origin.y = strongSelf.titleYPadding
            strongSelf.title.frame = r
        })
    }

    private func hideTitle(_ animated: Bool) {
        let dur = animated ? animationDuration : 0
        UIView.animate(withDuration: dur, delay: 0, options: UIView.AnimationOptions.beginFromCurrentState.union(.curveEaseIn), animations: { [weak self] in
            guard let strongSelf = self else { return }
            // Animation
            strongSelf.title.alpha = 0.0
            var r = strongSelf.title.frame
            r.origin.y = strongSelf.title.font.lineHeight + strongSelf.hintYPadding
            strongSelf.title.frame = r
        })
    }
}
