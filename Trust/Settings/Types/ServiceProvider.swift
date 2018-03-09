// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

enum URLServiceProvider {
    case twitter
    case reddit
    case facebook

    var title: String {
        switch self {
        case .twitter: return "Twitter"
        case .reddit: return "Reddit"
        case .facebook: return "Facebook"
        }
    }

    var localURL: URL? {
        switch self {
        case .twitter:
            return URL(string: "twitter://user?screen_name=\(Constants.twitterUsername)")!
        case .reddit:
            return URL(string: "reddit.com\(Constants.redditGroupName)")
        case .facebook:
            return URL(string: "fb://profile?id=\(Constants.facebookUsername)")
        }
    }

    var remoteURL: URL {
        return URL(string: self.remoteURLString)!
    }

    private var remoteURLString: String {
        switch self {
        case .twitter:
            return "https://twitter.com/\(Constants.twitterUsername)"
        case .reddit:
            return "https://reddit.com/\(Constants.redditGroupName)"
        case .facebook:
            return "https://www.facebook.com/\(Constants.facebookUsername)"
        }
    }

    var image: UIImage? {
        switch self {
        case .twitter: return R.image.settings_twitter()
        case .reddit: return R.image.settings_reddit()
        case .facebook: return R.image.settings_facebook()
        }
    }
}
