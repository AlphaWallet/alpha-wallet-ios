import UIKit
import AVFoundation

protocol ScannerViewControllerDelegate: AnyObject {
    func didScan(_ code: String)
}

final class ScannerViewController: UIViewController {
    
    weak var delegate: ScannerViewControllerDelegate?
    
    private let captureSession = AVCaptureSession()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            startCaptureSession(with: input)
            startVideoPreview()
        } catch {
            print("Error on capture setup: \(error)")
        }
    }
    
    private func startCaptureSession(with input: AVCaptureDeviceInput) {
        captureSession.addInput(input)
        let metadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]
        captureSession.startRunning()
    }
    
    private func startVideoPreview() {
        let videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoLayer.videoGravity = .resizeAspectFill
        videoLayer.frame = view.layer.bounds
        view.layer.insertSublayer(videoLayer, at: 0)
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection) {

        if let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            metadata.type == .qr,
            let qrCode = metadata.stringValue {
            delegate?.didScan(qrCode)
            dismiss(animated: true)
        }
    }
}
