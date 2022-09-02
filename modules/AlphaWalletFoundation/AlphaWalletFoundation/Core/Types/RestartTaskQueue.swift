// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

public class RestartTaskQueue {
    private (set) var queue: [Task]

    public enum Task: Equatable {
        //TODO make it unnecessary to restart UI after adding/removing a custom chain. At least have to start pricing fetching etc
        case addServer(CustomRPC)
        case editServer(original: CustomRPC, edited: CustomRPC)
        case removeServer(CustomRPC)
        case enableServer(RPCServer)
        case switchDappServer(server: RPCServer)
        case loadUrlInDappBrowser(URL)
        case reloadServers([RPCServer])
    }

    public init() {
        queue = .init()
    }

    public func add(_ task: Task) {
        queue.append(task)
    }

    public func remove(_ task: Task) {
        guard let index = queue.firstIndex(where: { $0 == task }) else { return }
        queue.remove(at: index)
    }
}
