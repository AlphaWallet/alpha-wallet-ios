// Copyright © 2018 Stormbird PTE. LTD.

import Combine
import AlphaWalletAddress
import AlphaWalletAttestation
import AlphaWalletCore
import AlphaWalletLogger
import AlphaWalletWeb3
import PromiseKit

fileprivate enum AttestationOrToken {
    case attestation(Attestation)
    case token(AlphaWallet.Address)
}

/// Manage access to and cache asset definition XML files
// swiftlint:disable type_body_length
public class AssetDefinitionStore: NSObject {
    public enum Result {
        case cached
        case updated
        case unmodified
        case error

        var isError: Bool {
            switch self {
            case .error:
                return true
            case .cached, .updated, .unmodified:
                return false
            }
        }
    }

    let features: TokenScriptFeatures
    private var lastContractInPasteboard: String?
    private var backingStore: AssetDefinitionBackingStore
    private let xmlHandlersForTokens: AtomicDictionary<AlphaWallet.Address, PrivateXMLHandler> = .init()
    private let xmlHandlersForAttestations: AtomicDictionary<Attestation.AttestationId, PrivateXMLHandler> = .init()
    private let baseXmlHandlers: AtomicDictionary<String, PrivateXMLHandler> = .init()
    private var signatureChangeSubject: PassthroughSubject<AlphaWallet.Address, Never> = .init()
    private var bodyChangeSubject: PassthroughSubject<AlphaWallet.Address, Never> = .init()
    private var attestationXmlChangeSubject: PassthroughSubject<Void, Never> = .init()
    private var listOfBadTokenScriptFilesSubject: CurrentValueSubject<[Filename], Never> = .init([])
    private let networking: AssetDefinitionNetworking
    private let tokenScriptStatusResolver: TokenScriptStatusResolver
    private let baseTokenScriptFiles: BaseTokenScriptFiles
    private let blockchainsProvider: BlockchainsProvider

    public let assetAttributeResolver: AssetAttributeResolver
    public var listOfBadTokenScriptFiles: AnyPublisher<[Filename], Never> {
        listOfBadTokenScriptFilesSubject.eraseToAnyPublisher()
    }

    public var conflictingTokenScriptFileNames: (official: [Filename], overrides: [Filename], all: [Filename]) {
        return backingStore.conflictingTokenScriptFileNames
    }

    public var signatureChange: AnyPublisher<AlphaWallet.Address, Never> {
        signatureChangeSubject.eraseToAnyPublisher()
    }

    public var bodyChange: AnyPublisher<AlphaWallet.Address, Never> {
        bodyChangeSubject.eraseToAnyPublisher()
    }

    public var attestationXMLChange: AnyPublisher<Void, Never> {
        attestationXmlChangeSubject.eraseToAnyPublisher()
    }

    public var assetsSignatureOrBodyChange: AnyPublisher<AlphaWallet.Address, Never> {
        return Publishers
            .Merge(signatureChange, bodyChange)
            .eraseToAnyPublisher()
    }

    private func assetBodyChanged(for contract: AlphaWallet.Address) -> AnyPublisher<Void, Never> {
        return bodyChangeSubject
            .filter { $0 == contract }
            .mapToVoid()
            .share()
            .eraseToAnyPublisher()
    }

    private func assetSignatureChanged(for contract: AlphaWallet.Address) -> AnyPublisher<Void, Never> {
        return signatureChangeSubject
            .filter { $0 == contract }
            .mapToVoid()
            .share()
            .eraseToAnyPublisher()
    }

    public func assetsSignatureOrBodyChange(for contract: AlphaWallet.Address) -> AnyPublisher<Void, Never> {
        return Publishers
            .Merge(assetSignatureChanged(for: contract), assetBodyChanged(for: contract))
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    public convenience init(backingStore optionalBackingStore: AssetDefinitionBackingStore? = nil, baseTokenScriptFiles: [TokenType: String] = [:], networkService: NetworkService, reachability: ReachabilityManagerProtocol = ReachabilityManager(), blockchainsProvider: BlockchainsProvider, features: TokenScriptFeatures, resetFolders: Bool) {
        let backingStore: AssetDefinitionBackingStore = optionalBackingStore ?? AssetDefinitionDiskBackingStoreWithOverrides(resetFolders: resetFolders)
        let baseTokenScriptFiles: BaseTokenScriptFiles = BaseTokenScriptFiles(baseTokenScriptFiles: baseTokenScriptFiles)
        let signatureVerifier = TokenScriptSignatureVerifier(baseTokenScriptFiles: baseTokenScriptFiles, networkService: networkService, features: features, reachability: reachability)
        self.init(backingStore: backingStore, baseTokenScriptFiles: baseTokenScriptFiles, signatureVerifier: signatureVerifier, networkService: networkService, blockchainsProvider: blockchainsProvider, features: features)
    }

    init(backingStore: AssetDefinitionBackingStore, baseTokenScriptFiles: BaseTokenScriptFiles, signatureVerifier: TokenScriptSignatureVerifieble, networkService: NetworkService, blockchainsProvider: BlockchainsProvider, features: TokenScriptFeatures) {
        self.features = features
        self.blockchainsProvider = blockchainsProvider
        self.networking = AssetDefinitionNetworking(networkService: networkService)
        self.backingStore = backingStore
        self.tokenScriptStatusResolver = TokenScriptStatusResolver(backingStore: backingStore, signatureVerifier: signatureVerifier)
        self.baseTokenScriptFiles = baseTokenScriptFiles
        assetAttributeResolver = AssetAttributeResolver(blockchainsProvider: blockchainsProvider)
        super.init()
        self.backingStore.delegate = self
        self.backingStore.resolver = self

        listOfBadTokenScriptFilesSubject.value = backingStore.badTokenScriptFileNames + backingStore.conflictingTokenScriptFileNames.all
    }

    //Calling this in >= iOS 14 will trigger a scary "AlphaWallet pasted from <app>" message
    public func enableFetchXMLForContractInPasteboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchXMLForContractInPasteboard), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    public func fetchXMLs(forContractsAndServers contractsAndServers: [AddressAndOptionalRPCServer]) {
        for each in contractsAndServers {
            fetchXML(forContract: each.address, server: each.server)
        }
    }

    /// useCacheAndFetch: when true, the completionHandler will be called immediately and a second time if an updated XML is fetched. When false, the completionHandler will only be called up fetching an updated XML
    ///
    /// IMPLEMENTATION NOTE: Current implementation will fetch the same XML multiple times if this function is called again before the previous attempt has completed. A check (which requires tracking completion handlers) hasn't been implemented because this doesn't usually happen in practice
    public func fetchXML(forContract contract: AlphaWallet.Address, server: RPCServer?, useCacheAndFetch: Bool = false, completionHandler: ((Result) -> Void)? = nil) {
        if useCacheAndFetch && backingStore.getXml(byContract: contract) != nil {
            completionHandler?(.cached)
        }

        //If we override with a TokenScript file that is for a contract that also has an official TokenScript file but the files are different, we'll enter an infinite recursion where we keep fetching the official TokenScript file, store it, think it has changed, invalid cache, re-download from the official repo and loops. The simple solution is to just not attempt to download or check against the official repo if the there's an overriding TokenScript file
        if !backingStore.isOfficial(contract: contract) {
            completionHandler?(.unmodified)
            return
        }

        urlToFetch(contract: contract, server: server)
            .receive(on: RunLoop.main)
            .sinkAsync(receiveCompletion: { result in
                guard case .failure(let error) = result else { return }
                //no-op
                warnLog("[TokenScript] unexpected error while fetching TokenScript file for contract: \(contract.eip55String) error: \(error)")
            }, receiveValue: { result in
                guard let (urls, isScriptUri) = result else { return }
                //TODO loop through the list of EIP-5169 URLs instead of only using the first
                guard let url = urls.first else { return }
                self.fetchXML(contract: contract, server: server, url: url, useCacheAndFetch: useCacheAndFetch) { result in
                    //Try a bit harder if the TokenScript was specified via EIP-5169 (`scriptURI()`)
                    //TODO probably better to convert completionHandler to Promise so we can retry more elegantly
                    if isScriptUri && result.isError {
                        self.fetchXML(contract: contract, server: server, url: url, useCacheAndFetch: useCacheAndFetch) { result in
                            if isScriptUri && result.isError {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    self.fetchXML(contract: contract, server: server, url: url, useCacheAndFetch: useCacheAndFetch, completionHandler: completionHandler)
                                }
                            }
                        }
                    } else {
                        completionHandler?(result)
                    }
                }
            })
    }

    public func fetchXMLAsync(forContract contract: AlphaWallet.Address, server: RPCServer?, useCacheAndFetch: Bool = false) async -> Result {
        return await withCheckedContinuation { continuation in
            fetchXML(forContract: contract, server: server, useCacheAndFetch: useCacheAndFetch) { result in
                continuation.resume(returning: result)
            }
        }
    }

    //Development/debug only
    public func debugFilenameHoldingAttestationScriptUri(forAttestation attestation: Attestation) -> URL? {
        guard let url = attestation.scriptUri else { return nil }
        return backingStore.debugGetPathToScriptUriFile(url: url)
    }

    public func fetchXMLForAttestationIfScriptURL(_ attestation: Attestation) async {
        guard let url = attestation.scriptUri else { return }
        //Cut down on unnecessary requests that would fail anyway
        if url.absoluteString == "https://script.uri" { return }
        if url.absoluteString == "ipfs://" { return }

        if url.isIpfs, attestationScriptUriTokenScriptHasDownloaded(url: url) { return }

        //TODO might have to improve downloading for intermittent failures. Currently, there are no-retries so even if the user re-gains connection, they have to restart app to download
        let request = AssetDefinitionNetworking.GetXmlFileRequest(url: url.rewrittenIfIpfs, lastModifiedDate: nil)

        return await withCheckedContinuation { continuation in
            networking.fetchXml(request: request)
                    .sinkAsync(receiveCompletion: { _ in
                        //no-op
                    }, receiveValue: { [weak self] response in
                        guard let strongSelf = self else {
                            continuation.resume(returning: ())
                            return
                        }

                        switch response {
                        case .error:
                            continuation.resume(returning: ())
                            return
                        case .unmodified:
                            continuation.resume(returning: ())
                            return
                        case .xml(let xml):
                            //Note that Alamofire converts the 304 to a 200 if caching is enabled (which it is, by default). So we'll never get a 304 here. Checking against Charles proxy will show that a 304 is indeed returned by the server with an empty body. So we compare the contents instead. https://github.com/Alamofire/Alamofire/issues/615
                            if xml == strongSelf.backingStore.getXml(byScriptUri: url) {
                                continuation.resume(returning: ())
                                return
                            } else if functional.isTruncatedXML(xml: xml) {
                                continuation.resume(returning: ())
                                return
                            } else {
                                strongSelf.handleDownloadedOfficialTokenScript(fromUrl: url, xml: xml, urlSource: AttestationOrToken.attestation(attestation))
                                continuation.resume(returning: ())
                            }
                        }
                    })
        }
    }

    private func fetchXML(contract: AlphaWallet.Address, server: RPCServer?, url: URL, useCacheAndFetch: Bool = false, completionHandler: ((Result) -> Void)? = nil) {
        let lastModified = backingStore.lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract)
        let request = AssetDefinitionNetworking.GetXmlFileRequest(url: url, lastModifiedDate: lastModified)

        networking.fetchXml(request: request)
            .sinkAsync(receiveCompletion: { _ in
                //no-op
            }, receiveValue: { [weak self] response in
                guard let strongSelf = self else { return }

                switch response {
                case .error:
                    completionHandler?(.error)
                case .unmodified:
                    completionHandler?(.unmodified)
                case .xml(let xml):
                    //Note that Alamofire converts the 304 to a 200 if caching is enabled (which it is, by default). So we'll never get a 304 here. Checking against Charles proxy will show that a 304 is indeed returned by the server with an empty body. So we compare the contents instead. https://github.com/Alamofire/Alamofire/issues/615
                    if xml == strongSelf.backingStore.getXml(byContract: contract) {
                        completionHandler?(.unmodified)
                    } else if functional.isTruncatedXML(xml: xml) {
                        strongSelf.fetchXML(forContract: contract, server: server, useCacheAndFetch: false) { result in
                            completionHandler?(result)
                        }
                    } else {
                        completionHandler?(.updated)
                        strongSelf.handleDownloadedOfficialTokenScript(fromUrl: url, xml: xml, urlSource: AttestationOrToken.token(contract))
                    }
                }
            })
    }

    private func handleDownloadedOfficialTokenScript(fromUrl url: URL, xml: String, urlSource: AttestationOrToken) {
        let attestation: Attestation?
        let contract: AlphaWallet.Address?
        switch urlSource {
        case .attestation(let source):
            attestation = source
            contract = nil
        case .token(let source):
            attestation = nil
            contract = source
        }

        //TODO Should create XMLHandler, to check if (attestation), if it affects a token. And if (token), if it affects an attestation. Remember this is official TS, not override

        if let attestation {
            backingStore.storeOfficialXmlForAttestation(attestation, withURL: url, xml: xml)
            _tokenScriptChanged(forAttestation: attestation)
        }

        if let contract {
            backingStore.storeOfficialXmlForToken(contract, xml: xml, fromUrl: url)
            _tokenScriptChanged(forContract: contract)
        }
    }

    @objc private func fetchXMLForContractInPasteboard() {
        guard let contents = UIPasteboard.general.string?.trimmed else { return }
        guard lastContractInPasteboard != contents else { return }
        guard CryptoAddressValidator.isValidAddress(contents) else { return }
        guard let address = AlphaWallet.Address(string: contents) else { return }
        defer { lastContractInPasteboard = contents }
        fetchXML(forContract: address, server: nil)
    }

    private func urlToFetch(contract: AlphaWallet.Address, server: RPCServer?) -> AnyPublisher<(urls: [URL], isScriptUri: Bool)?, Never> {
        let urlToFetchFromTokenScriptRepo: ([URL], Bool)? = functional.urlToFetchFromTokenScriptRepo(contract: contract).flatMap { ([$0], false) }

        if let server = server {
            return Just(server)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { [blockchainsProvider] server -> AnyPublisher<(urls: [URL], isScriptUri: Bool)?, SessionTaskError> in
                    guard let blockchain = blockchainsProvider.blockchain(with: server) else {
                        return .fail(SessionTaskError.responseError(SessionError.sessionNotFound))
                    }

                    return ScriptUri(blockchainProvider: blockchain).get(forContract: contract)
                        .map { ($0, true) }
                        .eraseToAnyPublisher()
                }.replaceError(with: urlToFetchFromTokenScriptRepo)
                .eraseToAnyPublisher()
        } else {
            return .just(urlToFetchFromTokenScriptRepo)
        }
    }

    private func attestationScriptUriTokenScriptHasDownloaded(url: URL) -> Bool {
        if let xml = backingStore.getXml(byScriptUri: url), !xml.isEmpty {
            return true
        } else {
            return false
        }
    }

    //Test only
    func getXml(byContract contract: AlphaWallet.Address) -> String? {
        return backingStore.getXml(byContract: contract)
    }

    //Test only
    func storeOfficialXmlForToken(_ contract: AlphaWallet.Address, xml: String, fromUrl url: URL) {
        backingStore.storeOfficialXmlForToken(contract, xml: xml, fromUrl: url)
    }

    private func privateXmlHandler(forContract contract: AlphaWallet.Address) -> PrivateXMLHandler {
        let xmlString = backingStore.getXml(byContract: contract)
        let isOfficial = backingStore.isOfficial(contract: contract)
        let isCanonicalized = backingStore.isCanonicalized(contract: contract)
        return PrivateXMLHandler(contract: contract, xmlString: xmlString, baseTokenType: nil, isOfficial: isOfficial, isCanonicalized: isCanonicalized, resolver: self, tokenScriptStatusResolver: tokenScriptStatusResolver, assetAttributeResolver: assetAttributeResolver, features: features)
    }

    //Should keep this function so we don't expose `optionalTokenType` to other callers. It usually shouldn't be `nil`
    public func tokenScriptStatus(forContract contract: AlphaWallet.Address) -> Promise<TokenLevelTokenScriptDisplayStatus> {
        return xmlHandler(forContract: contract, optionalTokenType: nil).tokenScriptStatus
    }

    //private because we don't want client code creating XMLHandler(s) to be able to accidentally pass in a nil TokenType
    private func xmlHandler(forContract contract: AlphaWallet.Address, optionalTokenType tokenType: TokenType?) -> XMLHandler {
        var privateXMLHandler: PrivateXMLHandler
        var baseXMLHandler: PrivateXMLHandler?
        if let handler = xmlHandlersForTokens[contract] {
            privateXMLHandler = handler
        } else {
            privateXMLHandler = privateXmlHandler(forContract: contract)
            xmlHandlersForTokens[contract] = privateXMLHandler
        }

        if features.isActivityEnabled, let tokenType = tokenType {
            let tokenTypeForBaseXml: TokenType
            if privateXMLHandler.hasValidTokenScriptFile, let tokenType = privateXMLHandler.tokenType {
                tokenTypeForBaseXml = TokenType(tokenInterfaceType: tokenType)
            } else {
                tokenTypeForBaseXml = tokenType
            }

            let key = functional.computeBasePrivateXMLHandlerKey(forContract: contract, tokenType: tokenTypeForBaseXml)
            if let handler = baseXmlHandlers[key] {
                baseXMLHandler = handler
            } else {
                if let xml = baseTokenScriptFiles.baseTokenScriptFile(for: tokenTypeForBaseXml) {
                    baseXMLHandler = PrivateXMLHandler(contract: contract, xmlString: xml, baseTokenType: tokenTypeForBaseXml, isOfficial: true, isCanonicalized: true, resolver: self, tokenScriptStatusResolver: tokenScriptStatusResolver, assetAttributeResolver: assetAttributeResolver, features: features)
                    baseXmlHandlers[key] = baseXMLHandler
                } else {
                    baseXMLHandler = nil
                }
            }
        } else {
            baseXMLHandler = nil
        }

        return XMLHandler(baseXMLHandler: baseXMLHandler, privateXMLHandler: privateXMLHandler)
    }

    fileprivate func create(forAttestation attestation: Attestation) -> PrivateXMLHandler? {
        let xmls = backingStore.getXmls(bySchemaId: attestation.schemaUid)
        for xmlString in xmls where !xmlString.isEmpty {
            let xmlHandler = PrivateXMLHandler(forAttestation: attestation, xmlString: xmlString, tokenScriptStatusResolver: tokenScriptStatusResolver, assetAttributeResolver: assetAttributeResolver, features: features)
            if xmlHandler.attestationCollectionId == xmlHandler.computeAttestationCollectionId(forAttestation: attestation) {
                return xmlHandler
            }
        }
        if let url = attestation.scriptUri, let xmlString = backingStore.getXml(byScriptUri: url), !xmlString.isEmpty {
            let xmlHandler = PrivateXMLHandler(forAttestation: attestation, xmlString: xmlString, tokenScriptStatusResolver: tokenScriptStatusResolver, assetAttributeResolver: assetAttributeResolver, features: features)
            if xmlHandler.attestationCollectionId == xmlHandler.computeAttestationCollectionId(forAttestation: attestation) {
                return xmlHandler
            }
        }
        return nil
    }

    public func deleteXmlFileDownloadedFromOfficialRepo(forContract contract: AlphaWallet.Address) {
        backingStore.deleteXmlFileDownloadedFromOfficialRepo(forContract: contract)
    }

    private func _tokenScriptChanged(forContract contract: AlphaWallet.Address) {
        xmlHandlersForTokens[contract] = nil
        bodyChangeSubject.send(contract)
        signatureChangeSubject.send(contract)
    }

    private func _tokenScriptChanged(forAttestations attestations: [Attestation]) {
        guard !attestations.isEmpty else { return }
        //TODO we only want to invalidate for those using scriptURIs only and not overridden with local TokenScript files, but this is easier and the performance hit should be low
        for each in attestations {
            xmlHandlersForAttestations[each.attestationId] = nil
        }
        attestationXmlChangeSubject.send()
    }

    private func _tokenScriptChanged(forAttestation attestation: Attestation) {
        _tokenScriptChanged(forAttestations: [attestation])
    }
}
// swiftlint:enable type_body_length

extension AssetDefinitionStore: TokenScriptResolver {
    public func xmlHandler(forContract contract: AlphaWallet.Address, tokenType: TokenType) -> XMLHandler {
        return xmlHandler(forContract: contract, optionalTokenType: tokenType)
    }

    public func xmlHandler(forAttestation attestation: Attestation) -> XMLHandler? {
        let attestationSigner = attestation.signer
        var privateXMLHandler: PrivateXMLHandler
        if let handler = xmlHandlersForAttestations[attestation.attestationId] {
            privateXMLHandler = handler
        } else {
            guard let handler = create(forAttestation: attestation) else { return nil }
            let issuerAddressDerivedFromTokenScriptFile = handler.attestationIssuerKey.flatMap { deriveAddressFromPublicKey($0) }
            privateXMLHandler = handler
            guard let issuerAddressDerivedFromTokenScriptFile, issuerAddressDerivedFromTokenScriptFile == attestationSigner else {
                infoLog("[TokenScript] Mismatch issuer public key in TokenScript file: \(handler.attestationIssuerKey) derived issuer address: \(String(describing: issuerAddressDerivedFromTokenScriptFile?.eip55String)) vs attestation's signer: \(attestationSigner.eip55String)")
                return nil
            }
            xmlHandlersForAttestations[attestation.attestationId] = privateXMLHandler
        }
        return XMLHandler(baseXMLHandler: nil, privateXMLHandler: privateXMLHandler)
    }

    //Must not cache the privateXMLHandler in this initializer because we are using it to "test" a freshly downloaded XML file
    public func xmlHandler(forAttestation attestation: Attestation, xmlString: String) -> XMLHandler {
        let privateXMLHandler = PrivateXMLHandler(forAttestation: attestation, xmlString: xmlString, tokenScriptStatusResolver: tokenScriptStatusResolver, assetAttributeResolver: assetAttributeResolver, features: features)
        return XMLHandler(baseXMLHandler: nil, privateXMLHandler: privateXMLHandler)
    }

    public func invalidateSignatureStatus(forContract contract: AlphaWallet.Address) {
        signatureChangeSubject.send(contract)
    }
}

extension AssetDefinitionStore: AssetDefinitionBackingStoreDelegate {
    public func tokenScriptChanged(forContractAndServer contractAndServer: AddressAndOptionalRPCServer) {
        _tokenScriptChanged(forContract: contractAndServer.address)
    }

    public func tokenScriptChanged(forAttestationSchemaUid schemaUid: Attestation.SchemaUid) {
        let attestations = AttestationsStore.allAttestations().filter { $0.schemaUid == schemaUid }
        _tokenScriptChanged(forAttestations: attestations)
    }

    public func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore) {
        //Careful to not fire immediately because even though we are on the main thread; while we are modifying the indices, we can't read from it or there'll be a crash
        DispatchQueue.main.async {
            self.listOfBadTokenScriptFilesSubject.value = self.backingStore.badTokenScriptFileNames + self.backingStore.conflictingTokenScriptFileNames.all
        }
    }
}

extension AssetDefinitionStore {
    enum functional {}
}

fileprivate extension AssetDefinitionStore.functional {
    static func isTruncatedXML(xml: String) -> Bool {
        //Safety check against a truncated file download
        return !xml.trimmed.hasSuffix(">")
    }

    static func computeBasePrivateXMLHandlerKey(forContract contract: AlphaWallet.Address, tokenType: TokenType) -> String {
        //Key cannot be just `contract`, because the type can change (from the overriding TokenScript file)
        return "\(contract.eip55String)-\(tokenType.rawValue)"
    }

    static func urlToFetchFromTokenScriptRepo(contract: AlphaWallet.Address) -> URL? {
        let name = contract.eip55String
        let url = URL(string: TokenScript.repoServer)?.appendingPathComponent(name)
        return url
    }
}

enum SessionError: Error {
    case sessionNotFound
}