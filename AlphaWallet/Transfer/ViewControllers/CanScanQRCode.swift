// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol CanScanQRCode: class {
    func promptUserOpenSettingsToChangeCameraPermission()
}

extension CanScanQRCode where Self: UIViewController {
    func promptUserOpenSettingsToChangeCameraPermission() {
        //TODO app will be killed by iOS after user changes camera permission. Ideally, we should note that the user has reached here and on app launch, prompt user if they want to resume
        confirm(
                title: R.string.localizable.cameraQrCodeDeniedPromptTitle(),
                message: R.string.localizable.cameraQrCodeDeniedPromptMessage(),
                okTitle: R.string.localizable.cameraQrCodeDeniedPromptButton(),
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
