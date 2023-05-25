//
//  BackgroundTaskService.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 24.04.2023.
//

import Foundation

public typealias BackgroundTaskIdentifier = String

public protocol BackgroundTaskService: AnyObject {
    func startTask() -> BackgroundTaskIdentifier
    func endTask(with identifier: BackgroundTaskIdentifier)
}

public class BackgroundTaskServiceImplementation: BackgroundTaskService {

    private struct Task {
        let id: String
        let taskIndentifier: UIBackgroundTaskIdentifier
    }

    private var tasks: [Task] = []
    private let queue = DispatchQueue(label: "queue", qos: .background)
    
    public init() { }

    public func startTask() -> BackgroundTaskIdentifier {
        let id = UUID().uuidString
        let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: id) {
            self.endTask(with: id)
        }

        let task = Task(id: id, taskIndentifier: backgroundTaskIdentifier)
        self.queue.async {
            self.tasks.append(task)
        }

        return id
    }

    public func endTask(with identifier: BackgroundTaskIdentifier) {
        self.queue.sync {
            if let index = self.tasks.firstIndex(where: { $0.id == identifier }) {
                let task = self.tasks[index]
                UIApplication.shared.endBackgroundTask(task.taskIndentifier)

                self.tasks.remove(at: index)
            }
        }
    }
}
