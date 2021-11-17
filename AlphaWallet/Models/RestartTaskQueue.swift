// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

class RestartTaskQueue {
    private (set) var queue: [Task]

    enum Task: Equatable {
        //TODO make it unnecessary to restart UI after adding/removing a custom chain. At least have to start pricing fetching etc
        case addServer(CustomRPC)
        case editServer(original: CustomRPC, edited: CustomRPC)
        case removeServer(CustomRPC)
        case enableServer(RPCServer)
        case switchDappServer(server: RPCServer)
        case loadUrlInDappBrowser(URL)
        case reloadServers([RPCServer])
    }

    init() {
        queue = .init()
    }

    func add(_ task: Task) {
        queue.append(task)
    }

    func remove(_ task: Task) {
        guard let index = queue.firstIndex(where: { $0 == task }) else { return }
        queue.remove(at: index)
    }
}
