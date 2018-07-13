//Adapted to monitor the contents of the directory, from https://github.com/krzysztofzablocki/KZFileWatchers. MIT
//Copyright (c) 2016 Krzysztof Zabłocki <krzysztof.zablocki@pixle.pl>

import Foundation

/// Monitor the contents of a given directory. Does not monitor subdirectories. E.g While monitoring /target/, if /target/f1 is created, we discover "f1", but when /target/f1/c1 is created, no changes will be detected
public enum DirectoryContentsWatcher {
    public enum RefreshResult {
        case noChanges
        case updated(contents: [String])
    }

    public typealias UpdateClosure = (RefreshResult) -> Void

    public enum Error: Swift.Error {

        /**
         Trying to perform operation on watcher that requires started state.
         */
        case notStarted

        /**
         Trying to start watcher that's already running.
         */
        case alreadyStarted

        /**
         Trying to stop watcher that's already stopped.
         */
        case alreadyStopped

        /**
         Failed to start the watcher, `reason` will contain more information why.
         */
        case failedToStart(reason: String)
    }
}

public protocol DirectoryContentsWatcherProtocol {
    /**
     Starts observing directory content changes, a watcher can only have one callback.

     - parameter closure: Closure to use for observations.

     - throws: `DirectoryContentsWatcher.Error`
     */
    func start(closure: @escaping DirectoryContentsWatcher.UpdateClosure) throws

    /**
     Stops observing changes.

     - throws: `DirectoryContentsWatcher.Error`
     */
    func stop() throws
}

public extension DirectoryContentsWatcher {
    // We don't necessary need the structure of a Local class within an enum as the "namespace", but just keeping it to be similar to the original codebase' structure
    public final class Local: DirectoryContentsWatcherProtocol {
        private typealias CancelBlock = () -> Void

        private enum State {
            case Started(source: DispatchSourceFileSystemObject, fileHandle: CInt, callback: DirectoryContentsWatcher.UpdateClosure, cancel: CancelBlock)
            case Stopped
        }

        private let path: String
        private let refreshInterval: TimeInterval
        private let queue: DispatchQueue
        private var state: State = .Stopped
        private var isProcessing: Bool = false
        private var cancelReload: CancelBlock?
        private var previousContent: [String: Date]?

        /**
         Initializes watcher to specified path.

         - parameter path:     Path of directory to observe.
         - parameter refreshInterval: Refresh interval to use for updates.
         - parameter queue:    Queue to use for firing `onChange` callback.

         - note: By default it throttles to 60 FPS, some editors can generate stupid multiple saves that mess with file system e.g. Sublime with AutoSave plugin is a mess and generates different file sizes, this will limit wasted time trying to load faster than 60 FPS, and no one should even notice it's throttled.
         */
        public init(path: String, refreshInterval: TimeInterval = 1/60, queue: DispatchQueue = DispatchQueue.main) {
            self.path = path
            self.refreshInterval = refreshInterval
            self.queue = queue
        }

        deinit {
            if case .Started = state {
                _ = try? stop()
            }
        }

        public func start(closure: @escaping DirectoryContentsWatcher.UpdateClosure) throws {
            guard case .Stopped = state else {
                throw Error.alreadyStarted
            }
            try startObserving(closure)
        }

        /**
         Stops observing changes.
         */
        public func stop() throws {
            guard case let .Started(_, _, _, cancel) = state else {
                throw Error.alreadyStopped
            }
            cancelReload?()
            cancelReload = nil
            cancel()

            isProcessing = false
            state = .Stopped
        }

        private func startObserving(_ closure: @escaping DirectoryContentsWatcher.UpdateClosure) throws {
            let handle = open(path, O_EVTONLY)

            if handle == -1 {
                throw Error.failedToStart(reason: "Failed to open directory")
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: handle,
                    eventMask: [.delete, .write, .extend, .attrib, .link, .rename, .revoke],
                    queue: queue
            )

            let cancelBlock = {
                source.cancel()
            }

            source.setEventHandler {
                let flags = source.data

                if flags.contains(.delete) || flags.contains(.rename) {
                    _ = try? self.stop()
                    do {
                        try self.startObserving(closure)
                    } catch {
                        self.queue.asyncAfter(deadline: .now() + self.refreshInterval) {
                            _ = try? self.startObserving(closure)
                        }
                    }
                    return
                }

                self.needsToReload()
            }

            source.setCancelHandler {
                close(handle)
            }

            source.resume()

            state = .Started(source: source, fileHandle: handle, callback: closure, cancel: cancelBlock)
            refresh()
        }

        private func needsToReload() {
            guard case .Started = state else { return }

            cancelReload?()
            cancelReload = throttle(after: refreshInterval) { self.refresh() }
        }

        /**
         Force refresh, can only be used if the watcher was started and it's not processing.
         */
        public func refresh() {
            guard case let .Started(_, _, closure, _) = state, isProcessing == false else {
                return
            }
            isProcessing = true

            let url = URL(fileURLWithPath: path)
            var contents = [String: Date]()

            if let paths = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey]) {
                for each in paths {
                    if let lastModified = try? each.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate as? Date {
                        contents[each.lastPathComponent] = lastModified
                    }
                }
            } else {
                isProcessing = false
                return
            }

            if let previousContent = previousContent {
                if contents != previousContent {
                    let filenames = self.keysWithDifferentValues(between: contents, and: previousContent)
                    self.previousContent = contents
                    queue.async {
                        closure(.updated(contents: filenames))
                    }
                } else {
                    queue.async {
                        closure(.noChanges)
                    }
                }
            } else {
                previousContent = contents
                queue.async {
                    closure(.noChanges)
                }
            }

            isProcessing = false
            cancelReload = nil
        }

        /// We don't check if date value is newer or older, because someone might drop an older file inside and it should be picked up
        private func keysWithDifferentValues(between dictionary1: [String: Date], and dictionary2: [String: Date]) -> [String] {
            var results = [String]()
            for (k, v) in dictionary1 {
                if v != dictionary2[k] {
                    results.append(k)
                }
            }
            let missingKeys = Array(dictionary2.keys) - Array(dictionary1.keys)
            results.append(contentsOf: missingKeys)
            return results
        }

        private func throttle(after: Double, action: @escaping () -> Void) -> CancelBlock {
            var isCancelled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + after) {
                if !isCancelled {
                    action()
                }
            }

            return {
                isCancelled = true
            }
        }
    }
}
