//
//  RunLoopThread.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.05.2022.
//

import UIKit

class RunLoopThread: Thread {

    override init() {
        super.init()
        let _ = NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        }
    }

    deinit {
        debugLog("[Thread] \(name ?? String(describing: self)) deallocated")
    }

    override func main() {
        autoreleasepool {
            debugLog("[Thread] \(name ?? String(describing: self)) started")

            let runLoop = RunLoop.current
            runLoop.add(Port(), forMode: RunLoop.Mode.default)

            while !isCancelled {
                _ = autoreleasepool {
                    runLoop.run(mode: RunLoop.Mode.default, before: Date.distantFuture)
                }
            }

            debugLog("[Thread] \(name ?? String(describing: self)) cancelled")
            Thread.exit()
        }
    }

    func performSync(_ block: @escaping () -> Swift.Void) {
        guard self.isExecuting else {
            if !self.isCancelled {
                debugLog("[Thread] \(name ?? String(describing: self)) hasn't started up yet. Starting soon...")
                Thread.sleep(forTimeInterval: 0.002)
                self.performSync(block)
            } else {
                debugLog("[Thread] \(name ?? String(describing: self)) has already been cancelled!")
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
        self.performSync() {
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
