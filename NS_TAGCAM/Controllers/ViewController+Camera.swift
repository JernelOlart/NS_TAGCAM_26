import UIKit
import AVFoundation
import CoreLocation

extension ViewController: AVCapturePhotoCaptureDelegate {
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        guard let videoDevice = bestCamera(for: .back) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                videoDeviceInput = videoInput
            }
        } catch { return }
        
        photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        captureSession.commitConfiguration()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
    }
    
    func bestCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: position) { return device }
        if let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: position) { return device }
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position) { return device }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) { return device }
        return nil
    }
    
    @objc func capturePhoto() {
        feedbackGenerator()
        UIView.animate(withDuration: 0.05, animations: { self.shutterView.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.1) { self.shutterView.alpha = 0 }
        }
        
        sessionQueue.async {
            guard let connection = self.photoOutput.connection(with: .video) else { return }
            if connection.isVideoOrientationSupported {
                let captureOrientation: AVCaptureVideoOrientation
                switch self.physicalOrientation {
                case .landscapeLeft: captureOrientation = .landscapeRight
                case .landscapeRight: captureOrientation = .landscapeLeft
                case .portraitUpsideDown: captureOrientation = .portraitUpsideDown
                default: captureOrientation = .portrait
                }
                connection.videoOrientation = captureOrientation
            }
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = self.flashMode
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { print(error); return }
        guard let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // we safely unwrap current location or use a default
            let location = self.currentLocation ?? CoreLocation.CLLocation()
            let watermarkedImage = self.addWatermark(image: image, location: location)
            
            DispatchQueue.main.async {
                self.imageView.image = watermarkedImage
                self.imageView.isHidden = false
                self.imageView.alpha = 0
                self.imageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                    self.imageView.alpha = 1
                    self.imageView.transform = .identity
                })
                
                self.previewTimer?.invalidate()
                self.previewTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                    UIView.animate(withDuration: 0.5, animations: {
                        self.imageView.alpha = 0
                        self.imageView.transform = CGAffineTransform(translationX: -100, y: 0)
                    }) { _ in
                        self.imageView.isHidden = true
                    }
                }
                UIImageWriteToSavedPhotosAlbum(watermarkedImage, nil, nil, nil)
            }
        }
    }
    
    func addWatermark(image: UIImage, location: CoreLocation.CLLocation) -> UIImage {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let watermarkText = """
        Latitud: \(location.coordinate.latitude)
        Longitud: \(location.coordinate.longitude)
        Elevación: \(location.altitude) m
        Precisión: \(location.horizontalAccuracy) m
        Fecha: \(dateFormatter.string(from: Date()))
        Dirección: \(address)
        """
        
        let fontSize: CGFloat = image.size.width * 0.025
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.black.withAlphaComponent(0.4)
        ]
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        let textPadding: CGFloat = image.size.width * 0.03
        let textHeight: CGFloat = image.size.height * 0.15
        let textRect = CGRect(x: textPadding, y: image.size.height - textHeight - textPadding, width: image.size.width - 2 * textPadding, height: textHeight)
        
        watermarkText.draw(in: textRect, withAttributes: textAttributes)
        
        if let logo = UIImage(named: "nsra") {
            let logoSize: CGFloat = image.size.width * 0.12
            let logoRect = CGRect(x: image.size.width - logoSize - textPadding, y: textPadding, width: logoSize, height: logoSize)
            logo.draw(in: logoRect, blendMode: .normal, alpha: 0.9)
        }
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? image
    }
}
