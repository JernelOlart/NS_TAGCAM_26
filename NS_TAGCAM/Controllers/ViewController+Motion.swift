import UIKit
import CoreMotion
import AVFoundation

extension ViewController {
    func setupMotionManager() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.2
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
                guard let data = data, error == nil else { return }
                self?.handleDeviceMotion(data)
            }
        }
    }
    
    func handleDeviceMotion(_ data: CMDeviceMotion) {
        let x = data.gravity.x
        let y = data.gravity.y
        
        let newOrientation: UIDeviceOrientation
        if abs(y) >= abs(x) {
            if y >= 0 {
                newOrientation = .portraitUpsideDown
            } else {
                newOrientation = .portrait
            }
        } else {
            if x >= 0 {
                newOrientation = .landscapeRight
            } else {
                newOrientation = .landscapeLeft
            }
        }
        
        if newOrientation != physicalOrientation {
            physicalOrientation = newOrientation
            updateUIForPhysicalOrientation()
        }
    }
    
    func updateUIForPhysicalOrientation() {
        UIView.animate(withDuration: 0.3) {
            let transform = self.controlRotationTransform()
            self.switchCameraButton.transform = transform
            self.flashButton.transform = transform
            self.gridButton.transform = transform
            self.controlsButton.transform = transform
            self.infoButton.transform = transform
        }

        updatePreviewLayerOrientation()
    }

    func controlRotationTransform(scale: CGFloat = 1.0) -> CGAffineTransform {
        let angle: CGFloat
        switch physicalOrientation {
        case .landscapeLeft: angle = .pi / 2
        case .landscapeRight: angle = -.pi / 2
        case .portraitUpsideDown: angle = .pi
        default: angle = 0
        }

        return CGAffineTransform(rotationAngle: angle).scaledBy(x: scale, y: scale)
    }

    func currentVideoRotationAngle() -> CGFloat {
        switch physicalOrientation {
        case .portrait: return 90
        case .landscapeLeft: return 0
        case .landscapeRight: return 180
        case .portraitUpsideDown: return 270
        default: return 90
        }
    }

    func updatePreviewLayerOrientation() {
        guard let connection = previewLayer?.connection else { return }
        let rotationAngle = currentVideoRotationAngle()
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }
}
