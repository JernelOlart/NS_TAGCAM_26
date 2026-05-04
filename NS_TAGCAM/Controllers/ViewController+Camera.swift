import UIKit
import AVFoundation
import CoreLocation

extension ViewController: AVCapturePhotoCaptureDelegate {
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
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
            if #available(iOS 16.0, *) {
                // In iOS 16+, high resolution is controlled via maxPhotoDimensions on settings
            } else {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
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
            
            let captureOrientation: AVCaptureVideoOrientation
            switch self.physicalOrientation {
            case .landscapeLeft: captureOrientation = .landscapeRight
            case .landscapeRight: captureOrientation = .landscapeLeft
            case .portraitUpsideDown: captureOrientation = .portraitUpsideDown
            default: captureOrientation = .portrait
            }
            
            if #available(iOS 17.0, *) {
                let rotationAngle: CGFloat
                switch captureOrientation {
                case .portrait: rotationAngle = 90
                case .portraitUpsideDown: rotationAngle = 270
                case .landscapeRight: rotationAngle = 0
                case .landscapeLeft: rotationAngle = 180
                @unknown default: rotationAngle = 90
                }
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = captureOrientation
                }
            }
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = self.flashMode
            
            if #available(iOS 16.0, *) {
                if let maxDimensions = self.photoOutput.constituentDevicePhotoDimensions.first(where: { $0.width > 0 }) {
                    photoSettings.maxPhotoDimensions = maxDimensions
                }
            } else {
                photoSettings.isHighResolutionPhotoEnabled = true
            }
            if #available(iOS 13.0, *) {
                photoSettings.photoQualityPrioritization = .quality
            }
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { print(error); return }
        guard let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) else { return }
        
        Task { @MainActor in
            let location = self.currentLocation ?? CoreLocation.CLLocation()
            let aspectRatio = self.currentAspectRatio
            let addressText = self.address
            
            // Process watermark in background to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                let croppedImage = self.cropToAspectRatio(image: image, aspectRatio: aspectRatio)
                let watermarkedImage = self.addWatermark(image: croppedImage, location: location, address: addressText)
                
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
    }
    
    nonisolated func addWatermark(image: UIImage, location: CoreLocation.CLLocation, address: String) -> UIImage {
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
        
        // Calculate dynamic sizes based on the smaller dimension to ensure consistency
        let minDimension = min(image.size.width, image.size.height)
        let fontSize: CGFloat = minDimension * 0.03
        let textPadding: CGFloat = minDimension * 0.04
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        // Calculate required text height dynamically
        let maxWidth = image.size.width - (textPadding * 2)
        let attributedString = NSAttributedString(string: watermarkText, attributes: textAttributes)
        let textBoundingRect = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: image.size.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        let backgroundHeight = textBoundingRect.height + (textPadding * 2)
        let backgroundRect = CGRect(x: 0, y: image.size.height - backgroundHeight, width: image.size.width, height: backgroundHeight)
        
        // Draw semi-transparent background for better readability
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context?.fill(backgroundRect)
        
        // Draw the text inside the background
        let textDrawingRect = CGRect(
            x: textPadding,
            y: image.size.height - backgroundHeight + textPadding,
            width: maxWidth,
            height: textBoundingRect.height
        )
        watermarkText.draw(in: textDrawingRect, withAttributes: textAttributes)
        
        // Draw logo as a watermark in the corner
        if let logo = UIImage(named: "nsra") {
            let logoSize: CGFloat = minDimension * 0.12
            let logoRect = CGRect(x: image.size.width - logoSize - textPadding, y: textPadding, width: logoSize, height: logoSize)
            logo.draw(in: logoRect, blendMode: .normal, alpha: 0.8)
        }
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? image
    }
    
    nonisolated func cropToAspectRatio(image: UIImage, aspectRatio: AspectRatio) -> UIImage {
        let originalSize = image.size
        let targetRatio: CGFloat
        switch aspectRatio {
        case .ratio4_3: targetRatio = 4.0 / 3.0
        case .ratio16_9: targetRatio = 16.0 / 9.0
        case .ratio1_1: targetRatio = 1.0
        }
        
        let currentRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        if currentRatio > targetRatio {
            newSize = CGSize(width: originalSize.height * targetRatio, height: originalSize.height)
        } else {
            newSize = CGSize(width: originalSize.width, height: originalSize.width / targetRatio)
        }
        
        let rect = CGRect(x: (originalSize.width - newSize.width) / 2, y: (originalSize.height - newSize.height) / 2, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        image.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? image
    }
}
