//
//  RunLoopThread.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.05.2022.
//

import UIKit

public class RunLoopThread: Thread {
    let isRunLoopThreadLoggingEnabled: Bool = Config().development.isRunLoopThreadLoggingEnabled

    public override init() {
        super.init()
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        }
    }

    deinit {
        if isRunLoopThreadLoggingEnabled {
            debugLog("[Thread] \(name ?? String(describing: self)) deallocated")
        }
    }

    public override func main() {
        autoreleasepool {
            if isRunLoopThreadLoggingEnabled {
                debugLog("[Thread] \(name ?? String(describing: self)) started")
            }
            let runLoop = RunLoop.current
            runLoop.add(Port(), forMode: RunLoop.Mode.default)

            while !isCancelled {
                _ = autoreleasepool {
                    runLoop.run(mode: RunLoop.Mode.default, before: Date.distantFuture)
                }
            }
            if isRunLoopThreadLoggingEnabled {
                debugLog("[Thread] \(name ?? String(describing: self)) cancelled")
            }
            Thread.exit()
        }
    }

    public func _perform(_ block: @escaping () -> Swift.Void) {
        guard self.isExecuting else {
            if !self.isCancelled {
                if isRunLoopThreadLoggingEnabled {
                    debugLog("[Thread] \(name ?? String(describing: self)) hasn't started up yet. Starting soon...")
                }
                Thread.sleep(forTimeInterval: 0.002)
                self._perform(block)
            } else {
                if isRunLoopThreadLoggingEnabled {
                    debugLog("[Thread] \(name ?? String(describing: self)) has already been cancelled!")
                }
            }
            return
        }
        self.perform(#selector(RunLoopThread.execute), on: self, with: BlockWrapper(block), waitUntilDone: true)
    }

    @objc fileprivate func execute(_ object: BlockWrapper) {
        let activity = ProcessInfo.processInfo.beginActivity(options: [.suddenTerminationDisabled, .automaticTerminationDisabled],
                                                             reason: "[Thread] \(self.name ?? "Thread") Doing Work")
        object.block()
        ProcessInfo.processInfo.endActivity(activity)
    }

    func stop() {
        self._perform() {
            self.cancel()
        }
    }
}

private class BlockWrapper: NSObject {
    let block: () -> Void

    init(_ block: @escaping () -> Void) {
        self.block = block

        super.init()
    }
}
