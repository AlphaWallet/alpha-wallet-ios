// Copyright © 2018 Stormbird PTE. LTD.

import Combine
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletLogger
import AlphaWalletWeb3
import PromiseKit

public protocol BaseTokenScriptFilesProvider: AnyObject {
    func containsTokenScriptFile(for file: XMLFile) -> Bool
    func baseTokenScriptFile(for tokenType: TokenType) -> XMLFile?
}

/// Manage access to and cache asset definition XML files
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

    public let features: TokenScriptFeatures

    private var lastContractInPasteboard: String?
    private var backingStore: AssetDefinitionBackingStore
    private let xmlHandlers: AtomicDictionary<AlphaWallet.Address, PrivateXMLHandler> = .init()
    private let baseXmlHandlers: AtomicDictionary<String, PrivateXMLHandler> = .init()
    private var signatureChangeSubject: PassthroughSubject<AlphaWallet.Address, Never> = .init()
    private var bodyChangeSubject: PassthroughSubject<AlphaWallet.Address, Never> = .init()
    private var listOfBadTokenScriptFilesSubject: CurrentValueSubject<[TokenScriptFileIndices.FileName], Never> = .init([])
    private let networking: AssetDefinitionNetworking
    private let tokenScriptStatusResolver: TokenScriptStatusResolver
    private let tokenScriptFilesProvider: BaseTokenScriptFilesProvider
    private let blockchainsProvider: BlockchainsProvider

    public let assetAttributeResolver: AssetAttributeResolver
    public var listOfBadTokenScriptFiles: AnyPublisher<[TokenScriptFileIndices.FileName], Never> {
        listOfBadTokenScriptFilesSubject.eraseToAnyPublisher()
    }

    public var conflictingTokenScriptFileNames: (official: [TokenScriptFileIndices.FileName], overrides: [TokenScriptFileIndices.FileName], all: [TokenScriptFileIndices.FileName]) {
        return backingStore.conflictingTokenScriptFileNames
    }

    public var contractsWithTokenScriptFileFromOfficialRepo: [AlphaWallet.Address] {
        return backingStore.contractsWithTokenScriptFileFromOfficialRepo
    }

    public var signatureChange: AnyPublisher<AlphaWallet.Address, Never> {
        signatureChangeSubject.eraseToAnyPublisher()
    }

    public var bodyChange: AnyPublisher<AlphaWallet.Address, Never> {
        bodyChangeSubject.eraseToAnyPublisher()
    }

    public var assetsSignatureOrBodyChange: AnyPublisher<AlphaWallet.Address, Never> {
        return Publishers
            .Merge(signatureChange, bodyChange)
            .eraseToAnyPublisher()
    }

    public func assetBodyChanged(for contract: AlphaWallet.Address) -> AnyPublisher<Void, Never> {
        return bodyChangeSubject
            .filter { $0 == contract }
            .mapToVoid()
            .share()
            .eraseToAnyPublisher()
    }

    public func assetSignatureChanged(for contract: AlphaWallet.Address) -> AnyPublisher<Void, Never> {
        return signatureChangeSubject
            .filter { $0 == contract }
            .mapToVoid()
            .share()
            .eraseToAnyPublisher()
    }

    public func assetsSignatureOrBodyChange(for contract: AlphaWallet.Address) -> AnyPublisher<Void, Never> {
        return Publishers
            .Merge(assetSignatureChanged(for: contract), assetSignatureChanged(for: contract))
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    convenience public init(backingStore: AssetDefinitionBackingStore = AssetDefinitionDiskBackingStoreWithOverrides(), baseTokenScriptFiles: [TokenType: String] = [:], networkService: NetworkService, reachability: ReachabilityManagerProtocol = ReachabilityManager(), blockchainsProvider: BlockchainsProvider, features: TokenScriptFeatures) {
        let baseTokenScriptFilesProvider: BaseTokenScriptFilesProvider = InMemoryTokenScriptFilesProvider(baseTokenScriptFiles: baseTokenScriptFiles)
        let signatureVerifier = TokenScriptSignatureVerifier(tokenScriptFilesProvider: baseTokenScriptFilesProvider, networkService: networkService, features: features, reachability: reachability)
        self.init(backingStore: backingStore, tokenScriptFilesProvider: baseTokenScriptFilesProvider, signatureVerifier: signatureVerifier, networkService: networkService, blockchainsProvider: blockchainsProvider, features: features)
    }

    public init(backingStore: AssetDefinitionBackingStore, tokenScriptFilesProvider: BaseTokenScriptFilesProvider, signatureVerifier: TokenScriptSignatureVerifieble, networkService: NetworkService, blockchainsProvider: BlockchainsProvider, features: TokenScriptFeatures) {
        self.features = features
        self.blockchainsProvider = blockchainsProvider
        self.networking = AssetDefinitionNetworking(networkService: networkService)
        self.backingStore = backingStore
        self.tokenScriptStatusResolver = BaseTokenScriptStatusResolver(backingStore: backingStore, signatureVerifier: signatureVerifier)
        self.tokenScriptFilesProvider = tokenScriptFilesProvider
        assetAttributeResolver = AssetAttributeResolver(blockchainsProvider: blockchainsProvider)
        super.init()
        self.backingStore.delegate = self

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
        if useCacheAndFetch && self[contract] != nil {
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
                guard let (url, isScriptUri) = result else { return }
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

    private func fetchXML(contract: AlphaWallet.Address, server: RPCServer?, url: URL, useCacheAndFetch: Bool = false, completionHandler: ((Result) -> Void)? = nil) {
        let lastModified = lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract)
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
                    if xml == strongSelf[contract] {
                        completionHandler?(.unmodified)
                    } else if strongSelf.isTruncatedXML(xml: xml) {
                        strongSelf.fetchXML(forContract: contract, server: server, useCacheAndFetch: false) { result in
                            completionHandler?(result)
                        }
                    } else {
                        strongSelf[contract] = xml
                        strongSelf.invalidate(forContract: contract)
                        completionHandler?(.updated)
                        strongSelf.triggerBodyChangedSubscribers(forContract: contract)
                        strongSelf.triggerSignatureChangedSubscribers(forContract: contract)
                    }
                }
            })
    }

    private func isTruncatedXML(xml: String) -> Bool {
        //Safety check against a truncated file download
        return !xml.trimmed.hasSuffix(">")
    }

    private func triggerBodyChangedSubscribers(forContract contract: AlphaWallet.Address) {
        bodyChangeSubject.send(contract)
    }

    private func triggerSignatureChangedSubscribers(forContract contract: AlphaWallet.Address) {
        signatureChangeSubject.send(contract)
    }

    @objc private func fetchXMLForContractInPasteboard() {
        guard let contents = UIPasteboard.general.string?.trimmed else { return }
        guard lastContractInPasteboard != contents else { return }
        guard CryptoAddressValidator.isValidAddress(contents) else { return }
        guard let address = AlphaWallet.Address(string: contents) else { return }
        defer { lastContractInPasteboard = contents }
        fetchXML(forContract: address, server: nil)
    }

    private func urlToFetch(contract: AlphaWallet.Address, server: RPCServer?) -> AnyPublisher<(url: URL, isScriptUri: Bool)?, Never> {
        let urlToFetchFromTokenScriptRepo = functional.urlToFetchFromTokenScriptRepo(contract: contract).flatMap { ($0, false) }

        if let server = server {
            return Just(server)
                .setFailureType(to: SessionTaskError.self)
                .flatMap { [blockchainsProvider] server -> AnyPublisher<(url: URL, isScriptUri: Bool)?, SessionTaskError> in
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

    private func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        return backingStore.lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract)
    }

    public func forEachContractWithXML(_ body: (AlphaWallet.Address) -> Void) {
        backingStore.forEachContractWithXML(body)
    }
}

extension AssetDefinitionStore: AssetDefinitionStoreProtocol {
    public subscript(contract: AlphaWallet.Address) -> String? {
        get { backingStore[contract] }
        set { backingStore[contract] = newValue }
    }

    public func isOfficial(contract: AlphaWallet.Address) -> Bool {
        return backingStore.isOfficial(contract: contract)
    }

    public func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        return backingStore.isCanonicalized(contract: contract)
    }

    public func getXmlHandler(for key: AlphaWallet.Address) -> PrivateXMLHandler? {
        return xmlHandlers[key]
    }

    public func set(xmlHandler: PrivateXMLHandler?, for key: AlphaWallet.Address) {
        xmlHandlers[key] = xmlHandler
    }

    public func getBaseXmlHandler(for key: String) -> PrivateXMLHandler? {
        baseXmlHandlers[key]
    }

    public func setBaseXmlHandler(for key: String, baseXmlHandler: PrivateXMLHandler?) {
        baseXmlHandlers[key] = baseXmlHandler
    }

    public func invalidateSignatureStatus(forContract contract: AlphaWallet.Address) {
        triggerSignatureChangedSubscribers(forContract: contract)
    }
}

extension AssetDefinitionStore: TokenScriptStatusResolver {
    public func computeTokenScriptStatus(forContract contract: AlphaWallet.Address, xmlString: String, isOfficial: Bool) -> Promise<TokenLevelTokenScriptDisplayStatus> {
        tokenScriptStatusResolver.computeTokenScriptStatus(forContract: contract, xmlString: xmlString, isOfficial: isOfficial)
    }
}

public final class InMemoryTokenScriptFilesProvider: BaseTokenScriptFilesProvider {
    private let _baseTokenScriptFiles: AtomicDictionary<TokenType, String> = .init()

    public init(baseTokenScriptFiles: [TokenType: String] = [:]) {
        _baseTokenScriptFiles.set(value: baseTokenScriptFiles)
    }

    public func containsTokenScriptFile(for file: XMLFile) -> Bool {
        return _baseTokenScriptFiles.contains(where: { $1 == file })
    }

    public func baseTokenScriptFile(for tokenType: TokenType) -> XMLFile? {
        return _baseTokenScriptFiles[tokenType]
    }
}

extension AssetDefinitionStore: BaseTokenScriptFilesProvider {
    public func containsTokenScriptFile(for file: XMLFile) -> Bool {
        return tokenScriptFilesProvider.containsTokenScriptFile(for: file)
    }

    public func baseTokenScriptFile(for tokenType: TokenType) -> XMLFile? {
        return tokenScriptFilesProvider.baseTokenScriptFile(for: tokenType)
    }
}

extension AssetDefinitionStore: AssetDefinitionBackingStoreDelegate {
    public func invalidateAssetDefinition(forContractAndServer contractAndServer: AddressAndOptionalRPCServer) {
        invalidate(forContract: contractAndServer.address)
        triggerBodyChangedSubscribers(forContract: contractAndServer.address)
        triggerSignatureChangedSubscribers(forContract: contractAndServer.address)
        //TODO check why we are fetching here. Current func gets called when on-disk changed too?
        fetchXML(forContract: contractAndServer.address, server: contractAndServer.server)
    }

    public func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore) {
        //Careful to not fire immediately because even though we are on the main thread; while we are modifying the indices, we can't read from it or there'll be a crash
        DispatchQueue.main.async {
            self.listOfBadTokenScriptFilesSubject.value = self.backingStore.badTokenScriptFileNames + self.backingStore.conflictingTokenScriptFileNames.all
        }
    }
}

extension AssetDefinitionStore {
    func invalidate(forContract contract: AlphaWallet.Address) {
        xmlHandlers[contract] = nil
    }
}

extension AssetDefinitionStore {
    enum functional {}
}

extension AssetDefinitionStore.functional {
    public static func urlToFetchFromTokenScriptRepo(contract: AlphaWallet.Address) -> URL? {
        let name = contract.eip55String
        let url = URL(string: TokenScript.repoServer)?.appendingPathComponent(name)
        return url
    }
}

enum SessionError: Error {
    case sessionNotFound
}
