// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import UIKit
import AlphaWalletAttestation
import AlphaWalletFoundation
import AlphaWalletTokenScript
import BigInt

protocol AttestationViewControllerDelegate: AnyObject, CanOpenURL {
}

class AttestationViewController: UIViewController {
    private let containerView: ScrollableStackView = ScrollableStackView()
    private let attributesStackView = GridStackView(viewModel: .init(edgeInsets: .init(top: 0, left: 16, bottom: 15, right: 16)))
    private let attestation: Attestation
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private var tokenScriptRendererView: TokenScriptWebView?
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: AttestationViewControllerDelegate?

    init(attestation: Attestation, wallet: Wallet, assetDefinitionStore: AssetDefinitionStore) {
        self.attestation = attestation
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        super.init(nibName: nil, bundle: nil)

        configure()
        subscribeForEthereumEventChanges()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        if let tokenScriptRendererView {
            tokenScriptRendererView.stopLoading()
        }
    }

    // swiftlint:disable function_body_length
    private func configure() {
        let xmlHandler = assetDefinitionStore.xmlHandler(forAttestation: attestation)
        let tokenScriptViewHtml: String
        let tokenScriptViewUrlFragment: String?
        let tokenScriptViewStyle: String
        if let xmlHandler {
            let (html, urlFragment, style) = xmlHandler.tokenViewHtml
            if html.isEmpty {
                tokenScriptRendererView?.removeFromSuperview()
                tokenScriptRendererView = nil
                tokenScriptViewHtml = ""
                tokenScriptViewUrlFragment = nil
                tokenScriptViewStyle = ""
            } else {
                tokenScriptRendererView = functional.createTokenScriptRendererView(attestation: attestation, wallet: wallet, assetDefinitionStore: assetDefinitionStore)
                tokenScriptViewHtml = html
                tokenScriptViewUrlFragment = urlFragment
                tokenScriptViewStyle = style
            }
        } else {
            tokenScriptRendererView?.removeFromSuperview()
            tokenScriptRendererView = nil
            tokenScriptViewHtml = ""
            tokenScriptViewUrlFragment = nil
            tokenScriptViewStyle = ""
        }

        title = xmlHandler?.getAttestationName() ?? attestation.name
        view.backgroundColor = Configuration.Color.Semantic.searchBarBackground

        var subviews: [UIView] = []

        if let tokenScriptRendererView {
            subviews.append(tokenScriptRendererView)
        }

        let detailsHeader = TokenInfoHeaderView()
        detailsHeader.configure(viewModel: TokenInfoHeaderViewModel(title: R.string.localizable.semifungiblesDetails()))
        subviews.append(detailsHeader)

        let networkRow = functional.createDetailRow(title: R.string.localizable.transactionNetworkLabelTitle(), value: TokenAttributeViewModel.defaultValueAttributedString(attestation.server.name))
        subviews.append(networkRow)

        let issuerAddressRow = functional.createDetailRow(title: R.string.localizable.aWalletContentsIssuerTitle(), value: TokenAttributeViewModel.urlValueAttributedString(attestation.signer.truncateMiddle))
        subviews.append(issuerAddressRow)
        issuerAddressRow.delegate = self

        if let xmlHandler, let description = xmlHandler.getAttestationDescription() {
            let descriptionRow = functional.createDetailRow(title: "", value: TokenAttributeViewModel.defaultValueAttributedString(description))
            subviews.append(descriptionRow)
        }

        let attributesHeader = TokenInfoHeaderView()
        attributesHeader.configure(viewModel: TokenInfoHeaderViewModel(title: R.string.localizable.attestationsAttributes()))
        subviews.append(attributesHeader)

        var attributeViews: [NonFungibleTraitView] = []

        let data: [Attestation.TypeValuePair]
        let fieldsSpecificationFromTokenScript: Bool
        if let xmlHandler {
            let attributes = xmlHandler.resolveAttestationAttributes(forAttestation: attestation)
            data = attributes
            fieldsSpecificationFromTokenScript = true
        } else {
            data = attestation.data
            fieldsSpecificationFromTokenScript = false
        }
        for each in data {
            let attributeView = functional.createAttributeView(name: each.type.name, value: each.value.stringValue)
            attributeViews.append(attributeView)
        }

        if !fieldsSpecificationFromTokenScript {
            let dateFormatter = Date.formatter(with: "dd MMM yyyy h:mm:ss a")
            let validFromView = functional.createAttributeView(name: R.string.localizable.attestationsValidFrom(), value: dateFormatter.string(from: attestation.time))
            attributeViews.append(validFromView)
            let expirationTimeString: String
            if let expirationTime = attestation.expirationTime {
                expirationTimeString = dateFormatter.string(from: expirationTime)
            } else {
                expirationTimeString = "—"
            }
            let validUntilView = functional.createAttributeView(name: R.string.localizable.attestationsValidUntil(), value: expirationTimeString)
            attributeViews.append(validUntilView)
        }

        attributesStackView.set(subviews: attributeViews)
        subviews.append(attributesStackView)

        containerView.stackView.removeAllArrangedSubviews()
        //remove from superview to remove constraints on it. This is especially important when show the TokenScript view, then when the TokenScript is updated and the view needs to removed
        containerView.removeFromSuperview()
        containerView.stackView.addArrangedSubviews(subviews)
        view.addSubview(containerView)

        var constraints: [NSLayoutConstraint] = [
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        if let tokenScriptRendererView {
            constraints.append(containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor))
            //The actual value doesn't matter as long as it's the same
            let dummyId: BigUInt = 0
            let tokenScriptHtml = wrapWithHtmlViewport(html: tokenScriptViewHtml, style: tokenScriptViewStyle, forTokenId: dummyId)
            tokenScriptRendererView.loadHtml(tokenScriptHtml, urlFragment: tokenScriptViewUrlFragment)
            tokenScriptRendererView.updateWithAttestation(attestation, withId: dummyId)
        }
        NSLayoutConstraint.activate(constraints)

        showIssuerKeyVerificationButton(xmlHandler: xmlHandler)
    }
    // swiftlint:enable function_body_length

    private func subscribeForEthereumEventChanges() {
        assetDefinitionStore.attestationXMLChange
            .sink { [weak self] _ in
                self?.configure()
            }.store(in: &cancelable)
    }

    private func showIssuerKeyVerificationButton(xmlHandler: XMLHandler?) {
        let verificationStatus: AttestationVerificationStatus = computeVerificationStatus(forAttestation: attestation, xmlHandler: xmlHandler)
        let issuerKeyVerificationButton = Self.functional.createIssuerKeyVerificationButton(verificationStatus: verificationStatus)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: issuerKeyVerificationButton)
    }

    enum functional {}
}

fileprivate extension AttestationViewController.functional {
    static func createAttributeView(name: String, value: String) -> NonFungibleTraitView {
        //Looks like it doesn't matter
        let indexPath = IndexPath(row: 0, section: 0)

        let attributeView = NonFungibleTraitView(edgeInsets: .init(top: 10, left: 10, bottom: 10, right: 10), indexPath: indexPath)
        let attributeViewModel = NonFungibleTraitViewModel(title: name, attributedValue: TokenAttributeViewModel.defaultValueAttributedString(value, alignment: .center), attributedCountValue: nil)
        attributeView.configure(viewModel: attributeViewModel)
        return attributeView
    }

    static func createDetailRow(title: String, value: NSAttributedString) -> TokenAttributeView {
        //Looks like it doesn't matter
        let indexPath = IndexPath(row: 0, section: 0)

        let viewModel: TokenAttributeViewModel = TokenAttributeViewModel(title: title, attributedValue: value)
        let view = TokenAttributeView(indexPath: indexPath)
        view.configure(viewModel: viewModel)
        return view
    }

    static func createIssuerKeyVerificationButton(verificationStatus: AttestationVerificationStatus) -> UIButton {
        let title: String
        let image: UIImage?
        let tintColor: UIColor
        let button = UIButton(type: .system)
        switch verificationStatus {
        case .trustedIssuer:
            //TODO localize
            title = "Trusted issuer"
            image = R.image.verified()
            tintColor = Configuration.Color.Semantic.textFieldContrastText
        case .untrustedIssuer:
            //TODO localize
            title = "Not trusted"
            image = R.image.unverified()
            tintColor = Configuration.Color.Semantic.defaultErrorText
        case .tokenScriptHasMatchingIssuer:
            //TODO localize
            title = ""
            image = nil
            tintColor = Configuration.Color.Semantic.textFieldContrastText
        }
        button.setTitle(title, for: .normal)
        button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.imageView?.tintColor = tintColor
        button.titleLabel?.font = Fonts.regular(size: 11)
        button.setTitleColor(tintColor, for: .normal)
        //TODO hardcoded margins don't work well across languages, e.g. for Chinese
        button.imageEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 12)
        button.titleEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: -12)
        return button
    }

    static func createTokenScriptRendererView(attestation: Attestation, wallet: Wallet, assetDefinitionStore: AssetDefinitionStore) -> TokenScriptWebView {
        let webView = TokenScriptWebView(server: attestation.server, serverWithInjectableRpcUrl: attestation.server, wallet: wallet.type, assetDefinitionStore: assetDefinitionStore)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        //TODO implement delegate if we need to use it
        //webView.delegate = self
        return webView
    }
}

extension AttestationViewController: TokenAttributeViewDelegate {
    func didSelect(in view: TokenAttributeView) {
        guard let contract = attestation.verifyingContract else { return }
        delegate?.didPressViewContractWebPage(forContract: contract, server: attestation.server, in: self)
    }
}