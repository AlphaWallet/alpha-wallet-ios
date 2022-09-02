// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public struct Favicon {
    public static func get(for url: URL?) -> URL? {
        guard let host = url?.host else { return nil }
        //Given the dapp URL being http://quickswap.exchange/#/pool (http, not https), the host is "quickswap.exchange", we will construct "https://www.google.com/s2/favicons?sz=256&domain_url=quickswap.exchange" and google.com will redirect it to "https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=http://quickswap.exchange&size=256" (note the "http" in front of "quickswap.exchange"). This unfortunately returns a `404`. So we always include `https://` below. This means it's possible that if a site is http-only, without https-support, google might not return a favicon. But this seems unlikely than the reverse (site is https and not http). We can't use `url?.scheme` because it might be `http://` when the URL is initially constructed.
        let url = URL(string: "https://www.google.com/s2/favicons?sz=256&domain_url=https://\(host)")
        return url
    }
}
