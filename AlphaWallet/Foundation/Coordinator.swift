// Copyright SIX DAY LLC. All rights reserved.

import Foundation

protocol Coordinator: AnyObject {
    var coordinators: [Coordinator] { get set }
}

extension Coordinator {
    func addCoordinator(_ coordinator: Coordinator) {
        coordinators.append(coordinator)
    }

    func removeCoordinator(_ coordinator: Coordinator) {
        coordinators = coordinators.filter { $0 !== coordinator }
    }

    func removeAllCoordinators() {
        coordinators.removeAll()
    }

    private func coordinatorOfType<T: Coordinator>(coordinator: Coordinator, type: T.Type) -> T? {
        if let value = coordinator as? T {
            return value
        } else {
            return coordinator.coordinators.compactMap { coordinatorOfType(coordinator: $0, type: type) }.first
        }
    }

    func coordinatorOfType<T: Coordinator>(type: T.Type) -> T? {
        return coordinatorOfType(coordinator: self, type: type)
    }
}
