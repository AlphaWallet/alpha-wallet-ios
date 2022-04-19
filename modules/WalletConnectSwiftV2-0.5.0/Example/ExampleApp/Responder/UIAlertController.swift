import UIKit

extension UIAlertController {
    
    static func createInputAlert(confirmHandler: @escaping (String) -> Void) -> UIAlertController {
        let alert = UIAlertController(title: "Paste URI", message: "Enter a WalletConnect URI to connect.", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let confirmAction = UIAlertAction(title: "Connect", style: .default) { _ in
            if let input = alert.textFields?.first?.text, !input.isEmpty {
                confirmHandler(input)
            }
        }
        alert.addTextField { textField in
            textField.placeholder = "wc://a14aefb980188fc35ec9..."
        }
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        alert.preferredAction = confirmAction
        return alert
    }
}
