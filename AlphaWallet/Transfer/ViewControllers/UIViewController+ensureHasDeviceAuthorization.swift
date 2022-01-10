// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AVFoundation

extension UIViewController {
    func ensureHasDeviceAuthorization() -> Bool {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            promptUserOpenSettingsToChangeCameraPermission()
            return false
        }
        return true
    }

    func promptUserOpenSettingsToChangeCameraPermission() {
        //TODO app will be killed by iOS after user changes camera permission. Ideally, we should note that the user has reached here and on app launch, prompt user if they want to resume
        confirm(
                title: R.string.localizable.cameraQrCodeDeniedPromptTitle(preferredLanguages: Languages.preferred()),
                message: R.string.localizable.cameraQrCodeDeniedPromptMessage(preferredLanguages: Languages.preferred()),
                okTitle: R.string.localizable.cameraQrCodeDeniedPromptButton(preferredLanguages: Languages.preferred()),
                okStyle: .default
        ) { result in
            switch result {
            case .success:
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
            case .failure:
                break
            }
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value) })
}
