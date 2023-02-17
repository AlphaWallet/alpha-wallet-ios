import UIKit

private func delegateClassName() -> String? {
    if NSClassFromString("XCTestCase") == nil {
        return NSStringFromClass(AppDelegate.self)
    } else {
        return nil
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, delegateClassName())