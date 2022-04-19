
import Foundation
@testable import Relayer

class AppStateObserverMock: AppStateObserving {
    var onWillEnterForeground: (() -> ())?
    var onWillEnterBackground: (() -> ())?
}
