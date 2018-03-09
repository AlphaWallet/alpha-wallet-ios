// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TicketRedemptionInfoViewController: UIViewController {
	let titleView = UILabel()
	let subtitleView = UILabel()
	let iconImageView = UIImageView()
	let addressLabel = UILabel()
	let contactLabel = UILabel()
	let middleBorder = UIView()
	let termsTitleLabel = UILabel()
	let termsBodyLabel = UILabel()

	init() {
		super.init(nibName: nil, bundle: nil)
		view.backgroundColor = Colors.appBackground

		let scrollView = UIScrollView()
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(scrollView)

		termsBodyLabel.numberOfLines = 0
		subtitleView.numberOfLines = 0
		addressLabel.numberOfLines = 0

		let stackView = UIStackView(arrangedSubviews: [
			titleView,
			subtitleView,
			iconImageView,
			addressLabel,
			contactLabel,
			middleBorder,
			termsTitleLabel,
			termsBodyLabel
		])
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.spacing = 18
		stackView.alignment = .center
		scrollView.addSubview(stackView)

		configure()

		let horizontalInset = CGFloat(20)
		NSLayoutConstraint.activate([
			scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			scrollView.topAnchor.constraint(equalTo: view.topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

			stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: horizontalInset),
			stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -horizontalInset),
			stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
			stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
			stackView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -2*horizontalInset),

			middleBorder.widthAnchor.constraint(equalTo: stackView.widthAnchor),
			middleBorder.heightAnchor.constraint(equalToConstant: 0.5),
		])
	}

	func configure() {
		titleView.textAlignment = .center
		subtitleView.textAlignment = .center
		subtitleView.textAlignment = .center
		addressLabel.textAlignment = .center
		contactLabel.textAlignment = .center
		termsTitleLabel.textAlignment = .center

		titleView.textColor = Colors.appWhite
		titleView.font = Fonts.light(size: 25)
		subtitleView.textColor = Colors.appWhite
		subtitleView.font = Fonts.regular(size: 15)
		addressLabel.textColor = Colors.appWhite
		addressLabel.font = Fonts.semibold(size: 15)
		contactLabel.textColor = Colors.appWhite
		contactLabel.font = Fonts.semibold(size: 15)
		termsTitleLabel.textColor = Colors.appWhite
		termsTitleLabel.font = Fonts.light(size: 25)
		termsBodyLabel.textColor = Colors.appWhite
		termsBodyLabel.font = Fonts.light(size: 15)

		middleBorder.backgroundColor = UIColor(red: 179, green: 223, blue: 239)

		titleView.text = "Redemption Locations"
		subtitleView.text = "Moscow Marriott Royal Aurora Hotel\n1st-10th June, 9:00-18:00"
		iconImageView.image = R.image.redemption_location()
		// swiftlint:disable:next line_length
		addressLabel.text = "Moscow Marriott Royal Aurora Hotel\naddress2Label.text\nPetrovka St-Bld 11, Moscow,\ngorod Moskva, Russia, 107031"
		contactLabel.text = "+7 495 937-10-00"
		termsTitleLabel.text = "Terms & Conditions"
		// swiftlint:disable:next line_length
		termsBodyLabel.text = "Lorem ipsum dolor sit amet, sit an nisl nibh affert. Et insolens liberavisse vis, usu noluisse neglegentur in. Mei aeque noluisse eu, vituperata ullamcorper ne eum, et per modus volumus. Clita mucius facilisi in sed, eam an postea convenire intellegat.\n\nEu sea omnesque praesent, aperiri eloquentiam reprehendunt quo et, quem veritus phaedrum usu no. Cu fuisset mediocritatem vim. Eu sed atqui deterruisset. Ei verear insolens nec. Vis id luptatum singulis aliquando, quidam nominati ne vel. Ea qui debet concludaturque, mel possit imperdiet philosophia ad. Congue pericula hendrerit mei ne.\n\nQuas ceteros ut duo, an eos probo verterem. Mel no rebum viris quaestio, bonorum erroribus instructior nec ut. Per adhuc liberavisse in. Ut vel tation postea, nec dolor definitiones eu."
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
}
