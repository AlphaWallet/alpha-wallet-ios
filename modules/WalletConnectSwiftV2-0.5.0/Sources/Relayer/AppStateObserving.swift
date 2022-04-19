
import Foundation
#if os(iOS)
import UIKit
#endif

protocol AppStateObserving {
    var onWillEnterForeground: (()->())? {get set}
    var onWillEnterBackground: (()->())? {get set}
}

class AppStateObserver: AppStateObserving {
    @objc var onWillEnterForeground: (() -> ())?
    
    @objc var onWillEnterBackground: (() -> ())?
    
    init() {
        subscribeNotificationCenter()
    }
    
    private func subscribeNotificationCenter() {
#if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil)
#endif
    }
    
    @objc
    private func appWillEnterBackground() {
        onWillEnterBackground?()
    }
    
    @objc
    private func appWillEnterForeground() {
        onWillEnterForeground?()
    }
    
}


