import UIKit
import AVFoundation

extension ViewController {
    
    @objc func toggleControls() {
        feedbackGenerator()
        isControlsVisible.toggle()
        controlsButton.tintColor = isControlsVisible ? .systemYellow : .white
        
        if isControlsVisible {
            updateSlidersFromCamera()
            UIView.animate(withDuration: 0.3) {
                self.advancedControlsStack.isHidden = false
                self.advancedControlsStack.alpha = 1
            }
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.advancedControlsStack.alpha = 0
            }) { _ in
                self.advancedControlsStack.isHidden = true
            }
        }
    }
    
    func updateSlidersFromCamera() {
        let device = videoDeviceInput.device
        isoSlider.minimumValue = Float(device.activeFormat.minISO)
        isoSlider.maximumValue = Float(device.activeFormat.maxISO)
        isoSlider.value = Float(device.iso)
        
        exposureSlider.minimumValue = Float(device.minExposureTargetBias)
        exposureSlider.maximumValue = Float(device.maxExposureTargetBias)
        exposureSlider.value = Float(device.exposureTargetBias)
    }
    
    @objc func isoChanged(_ sender: UISlider) {
        let device = videoDeviceInput.device
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: sender.value, completionHandler: nil)
            device.unlockForConfiguration()
        } catch { print(error) }
    }
    
    @objc func exposureChanged(_ sender: UISlider) {
        let device = videoDeviceInput.device
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(sender.value, completionHandler: nil)
            device.unlockForConfiguration()
        } catch { print(error) }
    }
    
    @objc func handleTapToFocus(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: view)
        guard let device = videoDeviceInput?.device else { return }
        
        let cameraPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = cameraPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = cameraPoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            focusSquare.center = touchPoint
            focusSquare.alpha = 1
            focusSquare.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            
            UIView.animate(withDuration: 0.3, animations: {
                self.focusSquare.transform = .identity
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 1.0, options: .curveEaseInOut, animations: {
                    self.focusSquare.alpha = 0
                })
            }
            
            if isControlsVisible {
                updateSlidersFromCamera()
            }
            
        } catch { print(error) }
    }
    
    @objc func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        }
    }
    
    @objc func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }
    
    @objc func toggleGrid() {
        isGridVisible.toggle()
        gridView.isHidden = !isGridVisible
        gridButton.tintColor = isGridVisible ? .systemYellow : .white
        feedbackGenerator()
    }
    
    @objc func toggleFlash() {
        feedbackGenerator()
        switch flashMode {
        case .auto:
            flashMode = .on
            flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
            flashButton.tintColor = .systemYellow
        case .on:
            flashMode = .off
            flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
            flashButton.tintColor = .white
        case .off:
            flashMode = .auto
            flashButton.setImage(UIImage(systemName: "bolt.badge.a.fill"), for: .normal)
            flashButton.tintColor = .white
        @unknown default: break
        }
    }
    
    @objc func switchCamera() {
        feedbackGenerator()
        sessionQueue.async {
            let currentPosition = self.videoDeviceInput.device.position
            let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
            guard let newDevice = self.bestCamera(for: newPosition) else { return }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                self.captureSession.beginConfiguration()
                self.captureSession.removeInput(self.videoDeviceInput)
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoDeviceInput = newInput
                } else {
                    self.captureSession.addInput(self.videoDeviceInput)
                }
                self.captureSession.commitConfiguration()
                
                DispatchQueue.main.async {
                    self.currentZoomFactor = 1.0
                    self.updateZoom(factor: 1.0)
                }
            } catch { print(error) }
        }
    }
    
    @objc func zoomButtonTapped(_ sender: UIButton) {
        feedbackGenerator()
        let zoomLevels: [CGFloat] = [0.5, 1.0, 2.0, 3.0]
        let selectedZoom = zoomLevels[sender.tag]
        updateZoom(factor: selectedZoom)
    }
    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            let factor = currentZoomFactor * gesture.scale
            updateZoom(factor: factor)
        } else if gesture.state == .ended {
            currentZoomFactor = max(0.5, min(currentZoomFactor * gesture.scale, 5.0))
        }
    }
    
    func updateZoom(factor: CGFloat) {
        let device = videoDeviceInput.device
        do {
            try device.lockForConfiguration()
            let minZoom = max(0.5, device.minAvailableVideoZoomFactor)
            let maxZoom = min(5.0, device.maxAvailableVideoZoomFactor)
            let zoom = min(max(factor, minZoom), maxZoom)
            device.videoZoomFactor = zoom
            device.unlockForConfiguration()
            
            self.currentZoomFactor = zoom
            
            DispatchQueue.main.async {
                let zoomLevels: [CGFloat] = [0.5, 1.0, 2.0, 3.0]
                var closestIndex = 1
                var minDiff = CGFloat.greatestFiniteMagnitude
                for (index, level) in zoomLevels.enumerated() {
                    let diff = abs(level - zoom)
                    if diff < minDiff {
                        minDiff = diff
                        closestIndex = index
                    }
                }
                
                for (index, view) in self.zoomStackView.arrangedSubviews.enumerated() {
                    if let btn = view as? UIButton {
                        btn.tintColor = (index == closestIndex) ? .systemYellow : .white
                    }
                }
            }
        } catch { print(error) }
    }
    
    func feedbackGenerator() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc func showInfoAlert() {
        feedbackGenerator()
        let currentYear = Calendar.current.component(.year, from: Date())
        let alert = UIAlertController(title: "NS TagCam", message: """
                Versión Premium
                Desarrollado por:
                Ing. Elián Hernández Olarte
                Email: Jernelx7@gmail.com
                Web: www.jernelsystems.com
                
                Copyright © \(currentYear) JernelSystems. All rights reserved.
                """, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Visitar Sitio Web", style: .default, handler: { _ in
            if let url = URL(string: "https://www.jernelsystems.com") {
                UIApplication.shared.open(url)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cerrar", style: .cancel))
        present(alert, animated: true)
    }
}
