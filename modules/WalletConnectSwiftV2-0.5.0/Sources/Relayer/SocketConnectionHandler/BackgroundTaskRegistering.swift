
import Foundation
#if os(iOS)
import UIKit
#endif

protocol BackgroundTaskRegistering {
    func beginBackgroundTask(name: String, completion: @escaping ()->())
    func endBackgroundTask()
}

class BackgroundTaskRegistrar: BackgroundTaskRegistering {
#if os(iOS)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
#endif

    func beginBackgroundTask(name: String, completion: @escaping () -> ()) {
    #if os(iOS)
        endBackgroundTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask (withName: name) { [unowned self] in
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            endBackgroundTask()
            completion()
        }
    #endif
    }

    func endBackgroundTask() {
    #if os(iOS)
        guard backgroundTaskID != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    #endif
    }
}
