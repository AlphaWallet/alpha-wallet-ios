// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

//Has a singleton; have to a static interface because of usage in our overridden version of `URLSessionConfiguration.overriddenProtocolClasses()`
public class TrackApiCalls: URLProtocol {
    private static let printInterval: TimeInterval = 10
    private static var counts: [String: Int] = .init()
    private static var timer: Timer?

    //Just to not expose the static interface to caller
    public static var shared: TrackApiCalls = .init()
    public static var isEnabled: Bool = false

    public func start() {
        guard !Self.isEnabled else { return }
        swizzle()
        Self.isEnabled = true
        Self.timer = Timer.scheduledTimer(withTimeInterval: Self.printInterval, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            let sorted = Self.counts.sorted { $0.value > $1.value }
            //TODO does this log too much data? especially from `tokenURI()` accesses? Also sorting would be slow if there's many records. Since this is for development, we'll observe
            infoLog("[TrackApiCalls] (sub)domains accessed: \(sorted.count). Calls for each (sub)domain: \(sorted)")
        }
    }

    private func stop() {
        Self.timer?.invalidate()
        Self.timer = nil
        Self.isEnabled = false
    }

    //This is not required since we are swizzling: `URLProtocol.registerClass(TrafficInterceptor.self)`
    private func swizzle() {
        let clazz: AnyClass = URLSessionConfiguration.self
        let method1 = class_getInstanceMethod(clazz, #selector(getter: clazz.protocolClasses))!
        let method2 = class_getInstanceMethod(clazz, #selector(URLSessionConfiguration.overriddenProtocolClasses))!

        method_exchangeImplementations(method1, method2)
    }

    public override func startLoading() {
        //no-op
    }

    public override func stopLoading() {
        //no-op
    }

    public override class func canInit(with task: URLSessionTask) -> Bool {
        clock(url: task.originalRequest?.url)
        return false
    }

    public override class func canInit(with request: URLRequest) -> Bool {
        clock(url: request.url)
        return false
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    private static func clock(url: URL?) {
        guard let domainName = url?.host else { return }
        DispatchQueue.main.async {
            let old = Self.counts[domainName, default: 0]
            Self.counts[domainName] = old + 1
        }
    }
}

extension URLSessionConfiguration {
    @objc func overriddenProtocolClasses() -> [AnyClass]? {
        guard let original = self.overriddenProtocolClasses() else { return [] }
        var results = original.filter { return $0 != TrackApiCalls.self }
        if TrackApiCalls.isEnabled {
            results.insert(TrackApiCalls.self, at: 0)
        }
        return results
    }
}
