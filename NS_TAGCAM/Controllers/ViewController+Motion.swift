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
        let angle: CGFloat
        switch physicalOrientation {
        case .landscapeLeft: angle = .pi / 2
        case .landscapeRight: angle = -.pi / 2
        case .portraitUpsideDown: angle = .pi
        default: angle = 0
        }
        
        UIView.animate(withDuration: 0.3) {
            let transform = CGAffineTransform(rotationAngle: angle)
            self.switchCameraButton.transform = transform
            self.flashButton.transform = transform
            self.gridButton.transform = transform
            self.controlsButton.transform = transform
            self.infoButton.transform = transform
        }
    }
    
    func updatePreviewLayerOrientation() {
        guard let connection = previewLayer?.connection else { return }
        let orientation = UIDevice.current.orientation
        if orientation.isValidInterfaceOrientation {
            switch orientation {
            case .portrait: connection.videoOrientation = .portrait
            case .landscapeLeft: connection.videoOrientation = .landscapeRight
            case .landscapeRight: connection.videoOrientation = .landscapeLeft
            case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
            default: connection.videoOrientation = .portrait
            }
        }
    }
}
