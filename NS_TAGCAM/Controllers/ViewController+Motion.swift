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
        updateHorizonIndicator(with: data)

        guard !isOrientationLocked else { return }

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
            requestSceneOrientationUpdate(for: newOrientation)
            updateUIForPhysicalOrientation()
        }
    }
    
    func updateUIForPhysicalOrientation() {
        updateAdaptiveLayout(animated: true)
        updatePreviewLayerOrientation()
    }

    func effectiveOrientation() -> UIDeviceOrientation {
        if isOrientationLocked, let lockedOrientation {
            return lockedOrientation
        }
        return physicalOrientation
    }

    func currentVideoRotationAngle() -> CGFloat {
        if let interfaceOrientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation {
            switch interfaceOrientation {
            case .portrait: return 90
            case .landscapeRight: return 0
            case .landscapeLeft: return 180
            case .portraitUpsideDown: return 270
            default: break
            }
        }

        switch effectiveOrientation() {
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

    func updateHorizonIndicator(with data: CMDeviceMotion) {
        let orientation = effectiveOrientation()
        let gravity = data.gravity

        let angle: CGFloat
        switch orientation {
        case .landscapeLeft:
            angle = CGFloat(atan2(gravity.y, gravity.x))
        case .landscapeRight:
            angle = CGFloat(atan2(-gravity.y, -gravity.x))
        case .portraitUpsideDown:
            angle = CGFloat(atan2(-gravity.x, gravity.y))
        default:
            angle = CGFloat(atan2(gravity.x, -gravity.y))
        }

        lastKnownLevelAngle = angle
        horizonLineView.transform = CGAffineTransform(rotationAngle: angle)

        let isLevel = abs(angle) < 0.08
        horizonLineView.backgroundColor = isLevel ? .systemGreen : UIColor.systemYellow.withAlphaComponent(0.9)
        horizonCenterDot.backgroundColor = isLevel ? .systemGreen : UIColor.white.withAlphaComponent(0.8)
    }

    func requestSceneOrientationUpdate(for orientation: UIDeviceOrientation) {
        guard let windowScene = view.window?.windowScene else { return }

        let targetMask: UIInterfaceOrientationMask
        switch orientation {
        case .landscapeLeft:
            targetMask = .landscapeRight
        case .landscapeRight:
            targetMask = .landscapeLeft
        case .portraitUpsideDown:
            targetMask = UIDevice.current.userInterfaceIdiom == .pad ? .portraitUpsideDown : .portrait
        case .portrait:
            targetMask = .portrait
        default:
            return
        }

        let currentOrientation = windowScene.effectiveGeometry.interfaceOrientation
        let targetOrientationMatchesCurrent: Bool
        switch (targetMask, currentOrientation) {
        case (.portrait, .portrait), (.portraitUpsideDown, .portraitUpsideDown),
             (.landscapeLeft, .landscapeLeft), (.landscapeRight, .landscapeRight):
            targetOrientationMatchesCurrent = true
        default:
            targetOrientationMatchesCurrent = false
        }

        guard !targetOrientationMatchesCurrent else { return }

        setNeedsUpdateOfSupportedInterfaceOrientations()
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: targetMask)
        windowScene.requestGeometryUpdate(preferences) { error in
            print("Orientation update error: \(error)")
        }
    }
}
