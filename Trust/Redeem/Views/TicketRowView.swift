// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TicketRowView: UIView {
	let checkboxImageView = UIImageView(image: R.image.ticket_bundle_unchecked())
	let background = UIView()
	let stateLabel = UILabel()
	let ticketCountLabel = UILabel()
	let titleLabel = UILabel()
	let venueLabel = UILabel()
	let dateLabel = UILabel()
	let seatRangeLabel = UILabel()
	let categoryLabel = UILabel()
	let dateImageView = UIImageView()
	let seatRangeImageView = UIImageView()
	let categoryImageView = UIImageView()
	let cityLabel = UILabel()
	let timeLabel = UILabel()
	let teamsLabel = UILabel()
	var detailsRowStack: UIStackView? = nil
    let showCheckbox: Bool
	var areDetailsVisible = false {
		didSet {
			detailsRowStack?.isHidden = !areDetailsVisible
		}
	}

	init(showCheckbox: Bool = false) {
        self.showCheckbox = showCheckbox

		super.init(frame: .zero)

		checkboxImageView.translatesAutoresizingMaskIntoConstraints = false
        if showCheckbox {
            addSubview(checkboxImageView)
        }

		background.translatesAutoresizingMaskIntoConstraints = false
		addSubview(background)

		let topRowStack = [ticketCountLabel, titleLabel].asStackView(spacing: 15, contentHuggingPriority: .required)
		let bottomRowStack = [dateImageView, dateLabel, .spacerWidth(7), seatRangeImageView, seatRangeLabel, .spacerWidth(7), categoryImageView, categoryLabel].asStackView(spacing: 7, contentHuggingPriority: .required)
		let detailsRow0 = [timeLabel, .spacerWidth(10), cityLabel].asStackView(contentHuggingPriority: .required)

		detailsRowStack = [
			.spacer(height: 10),
			detailsRow0,
			teamsLabel,
		].asStackView(axis: .vertical, contentHuggingPriority: .required)
		detailsRowStack?.isHidden = true

		//TODO variable names are unwieldy after several rounds of changes, fix them
		let stackView = [
			stateLabel,
			topRowStack,
			venueLabel,
			.spacer(height: 10),
			bottomRowStack,
			detailsRowStack!,
		].asStackView(axis: .vertical, contentHuggingPriority: .required)
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.alignment = .leading
		background.addSubview(stackView)

		// TODO extract constant. Maybe StyleLayout.sideMargin
		let xMargin  = CGFloat(7)
		let yMargin  = CGFloat(5)
		var checkboxRelatedConstraints = [NSLayoutConstraint]()
		if showCheckbox {
			checkboxRelatedConstraints.append(checkboxImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
			checkboxRelatedConstraints.append(checkboxImageView.centerYAnchor.constraint(equalTo: centerYAnchor))
			checkboxRelatedConstraints.append(background.leadingAnchor.constraint(equalTo: checkboxImageView.trailingAnchor, constant: xMargin))
			if ScreenChecker().isNarrowScreen() {
				checkboxRelatedConstraints.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 20))
				checkboxRelatedConstraints.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 20))
			} else {
				//Have to be hardcoded and not rely on the image's size because different string lengths for the text fields can force the checkbox to shrink
				checkboxRelatedConstraints.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 28))
				checkboxRelatedConstraints.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 28))
			}
		} else {
			checkboxRelatedConstraints.append(background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
		}

		NSLayoutConstraint.activate([
			stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
			stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
			stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
			stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),

			background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
			background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
			background.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -yMargin),

			stateLabel.heightAnchor.constraint(equalToConstant: 22),
		] + checkboxRelatedConstraints)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(viewModel: TicketRowViewModel) {
		background.backgroundColor = viewModel.contentsBackgroundColor
		background.layer.cornerRadius = 20
		background.layer.shadowRadius = 3
		background.layer.shadowColor = UIColor.black.cgColor
		background.layer.shadowOffset = CGSize(width: 0, height: 0)
		background.layer.shadowOpacity = 0.14
		background.layer.borderColor = UIColor.black.cgColor

		stateLabel.backgroundColor = viewModel.stateBackgroundColor
		stateLabel.layer.cornerRadius = 8
		stateLabel.clipsToBounds = true
		stateLabel.textColor = viewModel.stateColor
		stateLabel.font = viewModel.subtitleFont

		ticketCountLabel.textColor = viewModel.countColor
		ticketCountLabel.font = viewModel.ticketCountFont

		titleLabel.textColor = viewModel.titleColor
		titleLabel.font = viewModel.titleFont

		venueLabel.textColor = viewModel.titleColor
		venueLabel.font = viewModel.venueFont

		dateLabel.textColor = viewModel.subtitleColor
		dateLabel.font = viewModel.subtitleFont

		seatRangeLabel.textColor = viewModel.subtitleColor
		seatRangeLabel.font = viewModel.subtitleFont

		categoryLabel.textColor = viewModel.subtitleColor
		categoryLabel.font = viewModel.subtitleFont

		dateImageView.image = R.image.calendar()?.withRenderingMode(.alwaysTemplate)
		seatRangeImageView.image = R.image.ticket()?.withRenderingMode(.alwaysTemplate)
		categoryImageView.image = R.image.category()?.withRenderingMode(.alwaysTemplate)

		dateImageView.tintColor = viewModel.iconsColor
		seatRangeImageView.tintColor = viewModel.iconsColor
		categoryImageView.tintColor = viewModel.iconsColor

		cityLabel.textColor = viewModel.subtitleColor
		cityLabel.font = viewModel.detailsFont

		timeLabel.textColor = viewModel.subtitleColor
		timeLabel.font = viewModel.detailsFont

		teamsLabel.textColor = viewModel.subtitleColor
		teamsLabel.font = viewModel.detailsFont
	}
}
