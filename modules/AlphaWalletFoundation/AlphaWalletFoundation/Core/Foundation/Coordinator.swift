// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public protocol Coordinator: AnyObject {
    var coordinators: [Coordinator] { get set }
}

public extension Coordinator {
    public func addCoordinator(_ coordinator: Coordinator) {
        coordinators.append(coordinator)
    }

    public func removeCoordinator(_ coordinator: Coordinator) {
        assert(coordinator !== self)
        guard coordinator !== self else { return }
        coordinators = coordinators.filter { $0 !== coordinator }
    }

    public func removeAllCoordinators() {
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
