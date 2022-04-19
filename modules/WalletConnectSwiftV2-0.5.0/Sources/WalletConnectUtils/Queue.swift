
import Foundation

public class Queue<T> {
    private var elements: [T] = []
    private let serialQueue = DispatchQueue(label: "com.walletconnect.utils.queue")

    public var head: T? {
        serialQueue.sync {
            return elements.first
        }
    }
    
    public var tail: T? {
        serialQueue.sync {
            return elements.last
        }
    }
    
    public init(elements: [T] = []) {
        self.elements = elements
    }
    
    public func enqueue(_ value: T) {
        serialQueue.sync {
            elements.append(value)
        }
    }
    
    public func dequeue() -> T? {
        serialQueue.sync {
            if elements.isEmpty {
                return nil
            } else {
                return elements.removeFirst()
            }
        }
    }
}
