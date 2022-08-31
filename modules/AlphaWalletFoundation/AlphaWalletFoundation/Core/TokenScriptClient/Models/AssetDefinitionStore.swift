// Copyright © 2018 Stormbird PTE. LTD.

import Alamofire
import Combine
import PromiseKit

public protocol AssetDefinitionStoreDelegate: AnyObject {
    func listOfBadTokenScriptFilesChanged(in: AssetDefinitionStore)
}

public protocol BaseTokenScriptFilesProvider {
    var baseTokenScriptFiles: [TokenType: String] { get }
}

/// Manage access to and cache asset definition XML files
public class AssetDefinitionStore: NSObject {
    public enum Result {
        case cached
        case updated
        case unmodified
        case error
    }

    private var httpHeaders: HTTPHeaders = {
        guard let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return [:] }
        return [
            "Accept": "application/tokenscript+xml; charset=UTF-8",
            "X-Client-Name": TokenScript.repoClientName,
            "X-Client-Version": appVersion,
            "X-Platform-Name": TokenScript.repoPlatformName,
            "X-Platform-Version": UIDevice.current.systemVersion
        ]
    }()
    private var lastModifiedDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "E, dd MMM yyyy HH:mm:ss z"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
    private var lastContractInPasteboard: String?
    private var backingStore: AssetDefinitionBackingStore
    public let baseTokenScriptFiles: [TokenType: String]
    public weak var delegate: AssetDefinitionStoreDelegate?
    public var listOfBadTokenScriptFiles: [TokenScriptFileIndices.FileName] {
        return backingStore.badTokenScriptFileNames
    }
    public var conflictingTokenScriptFileNames: (official: [TokenScriptFileIndices.FileName], overrides: [TokenScriptFileIndices.FileName], all: [TokenScriptFileIndices.FileName]) {
        return backingStore.conflictingTokenScriptFileNames
    }

    public var contractsWithTokenScriptFileFromOfficialRepo: [AlphaWallet.Address] {
        return backingStore.contractsWithTokenScriptFileFromOfficialRepo
    }
    private var signatureChangeSubject: PassthroughSubject<AlphaWallet.Address, Never> = .init()
    private var bodyChangeSubject: PassthroughSubject<AlphaWallet.Address, Never> = .init()

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
            .filter { $0.sameContract(as: contract) }
            .map { _ in return () }
            .share()
            .eraseToAnyPublisher()
    }

    public func assetSignatureChanged(for contract: AlphaWallet.Address) -> AnyPublisher<Void, Never> {
        return signatureChangeSubject
            .filter { $0.sameContract(as: contract) }
            .map { _ in return () }
            .share()
            .eraseToAnyPublisher()
    }

    public func assetsSignatureOrBodyChange(for contract: AlphaWallet.Address) -> AnyPublisher<Void, Never> {
        return Publishers
            .Merge(assetSignatureChanged(for: contract), assetSignatureChanged(for: contract))
            .map { _ in return () }
            .eraseToAnyPublisher()
    }

    //TODO move
    public static var standardTokenScriptStyles: String {
        return """
               <style type="text/css">
               @font-face {
               font-family: 'SourceSansPro';
               src: url('\(Constants.tokenScriptUrlSchemeForResources)SourceSansPro-Light.otf') format('opentype');
               font-weight: lighter;
               }
               @font-face {
               font-family: 'SourceSansPro';
               src: url('\(Constants.tokenScriptUrlSchemeForResources)SourceSansPro-Regular.otf') format('opentype');
               font-weight: normal;
               }
               @font-face {
               font-family: 'SourceSansPro';
               src: url('\(Constants.tokenScriptUrlSchemeForResources)SourceSansPro-Semibold.otf') format('opentype');
               font-weight: bolder;
               }
               @font-face {
               font-family: 'SourceSansPro';
               src: url('\(Constants.tokenScriptUrlSchemeForResources)SourceSansPro-Bold.otf') format('opentype');
               font-weight: bold;
               }
               .token-card {
               padding: 0pt;
               margin: 0pt;
               }
               </style>
               """
    }
    private var cancelable = Set<AnyCancellable>()

    public init(backingStore: AssetDefinitionBackingStore = AssetDefinitionDiskBackingStoreWithOverrides(), baseTokenScriptFiles: [TokenType: String] = [:]) {
        self.backingStore = backingStore
        self.baseTokenScriptFiles = baseTokenScriptFiles
        super.init()
        self.backingStore.delegate = self
    }

    public func hasConflict(forContract contract: AlphaWallet.Address) -> Bool {
        return backingStore.hasConflictingFile(forContract: contract)
    }

    public func hasOutdatedTokenScript(forContract contract: AlphaWallet.Address) -> Bool {
        return backingStore.hasOutdatedTokenScript(forContract: contract)
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

    public subscript(contract: AlphaWallet.Address) -> String? {
        get {
            backingStore[contract]
        }
        set(value) {
            backingStore[contract] = value
        }
    }

    private func cacheXml(_ xml: String, forContract contract: AlphaWallet.Address) {
        backingStore[contract] = xml
    }

    public func isOfficial(contract: AlphaWallet.Address) -> Bool {
        return backingStore.isOfficial(contract: contract)
    }

    public func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        return backingStore.isCanonicalized(contract: contract)
    }

    /// useCacheAndFetch: when true, the completionHandler will be called immediately and a second time if an updated XML is fetched. When false, the completionHandler will only be called up fetching an updated XML
    ///
    /// IMPLEMENTATION NOTE: Current implementation will fetch the same XML multiple times if this function is called again before the previous attempt has completed. A check (which requires tracking completion handlers) hasn't been implemented because this doesn't usually happen in practice
    public func fetchXML(forContract contract: AlphaWallet.Address, server: RPCServer?, useCacheAndFetch: Bool = false, completionHandler: ((Result) -> Void)? = nil) {
        if useCacheAndFetch && self[contract] != nil {
            completionHandler?(.cached)
        }
        firstly {
            urlToFetch(contract: contract, server: server)
        }.done { url in
            guard let url = url else { return }
            self.fetchXML(forContract: contract, server: server, withUrl: url, useCacheAndFetch: useCacheAndFetch, completionHandler: completionHandler)
        }.catch { error in
            //no-op
            warnLog("[TokenScript] unexpected error while fetching TokenScript file for contract: \(contract.eip55String) error: \(error)")
        }
    }

    private func fetchXML(forContract contract: AlphaWallet.Address, server: RPCServer?, withUrl url: URL, useCacheAndFetch: Bool = false, completionHandler: ((Result) -> Void)? = nil) {
        Alamofire.request(
                url,
                method: .get,
                headers: httpHeadersWithLastModifiedTimestamp(forContract: contract)
        ).response { [weak self] response in
            guard let strongSelf = self else { return }
            if response.response?.statusCode == 304 {
                completionHandler?(.unmodified)
            } else if response.response?.statusCode == 406 {
                completionHandler?(.error)
            } else if response.response?.statusCode == 404 {
                completionHandler?(.error)
            } else if response.response?.statusCode == 200 {
                if let xml = response.data.flatMap({ String(data: $0, encoding: .utf8) }).nilIfEmpty {
                    //Note that Alamofire converts the 304 to a 200 if caching is enabled (which it is, by default). So we'll never get a 304 here. Checking against Charles proxy will show that a 304 is indeed returned by the server with an empty body. So we compare the contents instead. https://github.com/Alamofire/Alamofire/issues/615
                    if xml == strongSelf[contract] {
                        completionHandler?(.unmodified)
                    } else if strongSelf.isTruncatedXML(xml: xml) {
                        strongSelf.fetchXML(forContract: contract, server: server, useCacheAndFetch: false) { result in
                            completionHandler?(result)
                        }
                    } else {
                        strongSelf.cacheXml(xml, forContract: contract)
                        XMLHandler.invalidate(forContract: contract)
                        completionHandler?(.updated)
                        strongSelf.triggerBodyChangedSubscribers(forContract: contract)
                        strongSelf.triggerSignatureChangedSubscribers(forContract: contract)
                    }
                } else {
                    completionHandler?(.error)
                }
            }
        }
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

    private func urlToFetch(contract: AlphaWallet.Address, server: RPCServer?) -> Promise<URL?> {
        if let server = server {
            return firstly {
                Self.functional.urlToFetchFromScriptUri(contract: contract, server: server)
            }.map {
                $0
            }.recover { _ -> Promise<URL?> in
                Self.functional.urlToFetchFromTokenScriptRepo(contract: contract)
            }
        } else {
            return Self.functional.urlToFetchFromTokenScriptRepo(contract: contract)
        }
    }

    private func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        return backingStore.lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract)
    }

    private func httpHeadersWithLastModifiedTimestamp(forContract contract: AlphaWallet.Address) -> HTTPHeaders {
        var result = httpHeaders
        if let lastModified = lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract) {
            result["IF-Modified-Since"] = string(fromLastModifiedDate: lastModified)
            return result
        } else {
            return result
        }
    }

    public func string(fromLastModifiedDate date: Date) -> String {
        return lastModifiedDateFormatter.string(from: date)
    }

    public func forEachContractWithXML(_ body: (AlphaWallet.Address) -> Void) {
        backingStore.forEachContractWithXML(body)
    }

    public func invalidateSignatureStatus(forContract contract: AlphaWallet.Address) {
        triggerSignatureChangedSubscribers(forContract: contract)
    }

    public func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return backingStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString)
    }

    public func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        return backingStore.writeCacheTokenScriptSignatureVerificationType(verificationType, forContract: contract, forXmlString: xmlString)
    }

    public func contractDeleted(_ contract: AlphaWallet.Address) {
        XMLHandler.invalidate(forContract: contract)
        backingStore.deleteFileDownloadedFromOfficialRepoFor(contract: contract)
    }
}

extension AssetDefinitionStore: BaseTokenScriptFilesProvider {}

extension AssetDefinitionStore: AssetDefinitionBackingStoreDelegate {
    public func invalidateAssetDefinition(forContractAndServer contractAndServer: AddressAndOptionalRPCServer) {
        XMLHandler.invalidate(forContract: contractAndServer.address)
        triggerBodyChangedSubscribers(forContract: contractAndServer.address)
        triggerSignatureChangedSubscribers(forContract: contractAndServer.address)
        //TODO check why we are fetching here. Current func gets called when on-disk changed too?
        fetchXML(forContract: contractAndServer.address, server: contractAndServer.server)
    }

    public func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore) {
        //Careful to not fire immediately because even though we are on the main thread; while we are modifying the indices, we can't read from it or there'll be a crash
        DispatchQueue.main.async {
            self.delegate?.listOfBadTokenScriptFilesChanged(in: self)
        }
    }
}

extension AssetDefinitionStore {
    enum functional {}
}

extension AssetDefinitionStore.functional {
    public static func urlToFetchFromTokenScriptRepo(contract: AlphaWallet.Address) -> Promise<URL?> {
        let name = contract.eip55String
        let url = URL(string: TokenScript.repoServer)?.appendingPathComponent(name)
        return .value(url)
    }

    public static func urlToFetchFromScriptUri(contract: AlphaWallet.Address, server: RPCServer) -> Promise<URL> {
        ScriptUri(forServer: server).get(forContract: contract)
    }
}
