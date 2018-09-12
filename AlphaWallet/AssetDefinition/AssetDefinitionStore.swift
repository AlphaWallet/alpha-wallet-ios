// Copyright © 2018 Stormbird PTE. LTD.

import Alamofire

/// Manage access to and cache asset definition XML files
class AssetDefinitionStore {
    enum Result {
        case cached
        case updated
        case unmodified
        case error
    }

    private var httpHeaders: HTTPHeaders = {
        guard let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return [:] }
        return [
            "Accept": "text/xml; charset=UTF-8",
            "X-Client-Name": Constants.repoClientName,
            "X-Client-Version": appVersion,
            "X-Platform-Name": Constants.repoPlatformName,
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
    private var subscribers: [(String) -> Void] = []
    private var backingStore: AssetDefinitionBackingStore

    init(backingStore: AssetDefinitionBackingStore = AssetDefinitionDiskBackingStoreWithOverrides()) {
        self.backingStore = backingStore
        self.backingStore.delegate = self
    }

    func enableFetchXMLForContractInPasteboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchXMLForContractInPasteboard), name: .UIApplicationDidBecomeActive, object: nil)
    }

    func fetchXMLs(forContracts contracts: [String]) {
        for each in contracts {
            fetchXML(forContract: each)
        }
    }

    subscript(contract: String) -> String? {
        get {
            return backingStore[contract]
        }
        set(xml) {
            backingStore[contract] = xml
        }
    }

    func isOfficial(contract: String) -> Bool {
        return backingStore.isOfficial(contract: contract)
    }

    func subscribe(_ subscribe: @escaping (_ contract: String) -> Void) {
        subscribers.append(subscribe)
    }

    /// useCacheAndFetch: when true, the completionHandler will be called immediately and a second time if an updated XML is fetched. When false, the completionHandler will only be called up fetching an updated XML
    ///
    /// IMPLEMENTATION NOTE: Current implementation will fetch the same XML multiple times if this function is called again before the previous attempt has completed. A check (which requires tracking completion handlers) hasn't been implemented because this doesn't usually happen in practice
    func fetchXML(forContract contract: String, useCacheAndFetch: Bool = false, completionHandler: ((Result) -> Void)? = nil) {
        let contract = contract.add0x.lowercased()
        if useCacheAndFetch && self[contract] != nil {
            completionHandler?(.cached)
        }
        guard let url = urlToFetch(contract: contract) else { return }
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
            } else {
                if let data = response.data, let xml = String(data: data, encoding: .utf8), !xml.isEmpty {
                    strongSelf[contract] = xml
                    XMLHandler.invalidate(forContract: contract)
                    completionHandler?(.updated)
                    strongSelf.subscribers.forEach { $0(contract) }
                } else {
                    completionHandler?(.error)
                }
            }
        }
    }

    @objc private func fetchXMLForContractInPasteboard() {
        guard let contents = UIPasteboard.general.string?.trimmed else { return }
        guard lastContractInPasteboard != contents else { return }
        guard CryptoAddressValidator.isValidAddress(contents) else { return }
        defer { lastContractInPasteboard = contents }
        fetchXML(forContract: contents)
    }

    private func urlToFetch(contract: String) -> URL? {
        let name = backingStore.standardizedName(ofContract: contract)
        return URL(string: Constants.repoServer)?.appendingPathComponent(name)
    }

    private func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: String) -> Date? {
        return backingStore.lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract)
    }

    private func httpHeadersWithLastModifiedTimestamp(forContract contract: String) -> HTTPHeaders {
        var result = httpHeaders
        if let lastModified = lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract) {
            result["IF-Modified-Since"] = string(fromLastModifiedDate: lastModified)
            return result
        } else {
            return result
        }
    }

    func string(fromLastModifiedDate date: Date) -> String {
        return lastModifiedDateFormatter.string(from: date)
    }

    func forEachContractWithXML(_ body: (String) -> Void) {
        backingStore.forEachContractWithXML(body)
    }
}

extension AssetDefinitionStore: AssetDefinitionBackingStoreDelegate {
    func invalidateAssetDefinition(forContract contract: String) {
        XMLHandler.invalidate(forContract: contract)
        subscribers.forEach { $0(contract) }
        fetchXML(forContract: contract)
    }
}
