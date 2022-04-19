
import Foundation
@testable import Relayer

class BackgroundTaskRegistrarMock: BackgroundTaskRegistering {
    var completion: (()->())?
    
    func beginBackgroundTask(name: String, completion: @escaping () -> ()) {
        self.completion = completion
    }

    func endBackgroundTask() {

    }
}
