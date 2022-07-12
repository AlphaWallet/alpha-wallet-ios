// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

protocol EnableServersHeaderViewDelegate: AnyObject {
    func toggledTo(_ newValue: Bool, headerView: EnableServersHeaderView)
}

class EnableServersHeaderView: UIView {
    private let label = UILabel()
    private let toggle = UISwitch()
    private let bottomSeparatorView = UIView.tableHeaderFooterViewSeparatorView()

    var mode: EnabledServersViewModel.Mode
    weak var delegate: EnableServersHeaderViewDelegate?

    override init(frame: CGRect) {
        mode = .mainnet

        super.init(frame: CGRect())

        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)

        let stackView = [.spacerWidth(16), label, .spacer(), toggle, .spacerWidth(16)].asStackView(axis: .horizontal, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        addSubview(bottomSeparatorView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),

            bottomSeparatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSeparatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSeparatorView.topAnchor.constraint(equalTo: stackView.bottomAnchor),
            bottomSeparatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(mode: EnabledServersViewModel.Mode, isEnabled: Bool) {
        self.mode = mode
        backgroundColor  = Configuration.Color.Semantic.tableViewHeaderBackground

        label.backgroundColor = Configuration.Color.Semantic.tableViewHeaderBackground
        label.textColor = Configuration.Color.Semantic.tableViewCellPrimaryFont
        label.font = Fonts.tableHeader
        label.text = mode.headerText

        toggle.isOn = isEnabled
    }

    func toggle(isEnabled: Bool) {
        toggle.isOn = isEnabled
    }
    
    @objc private func toggled() {
        delegate?.toggledTo(toggle.isOn, headerView: self)
    }
}
