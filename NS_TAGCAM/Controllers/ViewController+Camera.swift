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
            configurePhotoOutputForBestQuality(using: videoDevice)
        }
        
        captureSession.commitConfiguration()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        preparePhotoCapturePipeline()
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

            let rotationAngle = self.currentVideoRotationAngle()
            if connection.isVideoRotationAngleSupported(rotationAngle) {
                connection.videoRotationAngle = rotationAngle
            }
            let photoSettings = self.makePhotoSettingsForBestQuality()
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func configurePhotoOutputForBestQuality(using device: AVCaptureDevice) {
        if #available(iOS 13.0, *) {
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        if #available(iOS 16.0, *) {
            if let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
                Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
            }) {
                photoOutput.maxPhotoDimensions = maxDimensions
            }
        } else {
            photoOutput.isHighResolutionCaptureEnabled = true
        }

        if photoOutput.isContentAwareDistortionCorrectionSupported {
            photoOutput.isContentAwareDistortionCorrectionEnabled = true
        }
    }

    func makePhotoSettingsForBestQuality() -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }

        settings.flashMode = flashMode

        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }

        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .quality
        }

        settings.isAutoRedEyeReductionEnabled = photoOutput.isAutoRedEyeReductionSupported

        if photoOutput.isContentAwareDistortionCorrectionSupported {
            settings.isAutoContentAwareDistortionCorrectionEnabled = true
        }

        if photoOutput.isVirtualDeviceFusionSupported {
            settings.isAutoVirtualDeviceFusionEnabled = true
        }

        return settings
    }

    func preparePhotoCapturePipeline() {
        let preparedSettings = makePhotoSettingsForBestQuality()
        photoOutput.setPreparedPhotoSettingsArray([preparedSettings], completionHandler: nil)
    }
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { print(error); return }
        guard let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) else { return }
        
        Task { @MainActor in
            let location = self.currentLocation ?? CoreLocation.CLLocation()
            let aspectRatio = self.currentAspectRatio
            let addressText = self.address
            let configuration = self.currentWatermarkConfiguration()
            let mapSnapshot = configuration.showsMiniMap ? self.currentMapSnapshot : nil
            
            // Process watermark in background to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                let croppedImage = self.cropToAspectRatio(image: image, aspectRatio: aspectRatio)
                let watermarkedImage = self.addWatermark(
                    image: croppedImage,
                    location: location,
                    address: addressText,
                    configuration: configuration,
                    mapSnapshot: mapSnapshot
                )
                
                DispatchQueue.main.async {
                    self.imageView.image = watermarkedImage
                    self.imageView.alpha = 0
                    self.imageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                    
                    UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                        self.imageView.alpha = 1
                        self.imageView.transform = .identity
                    }) 
                    
                    self.previewTimer?.invalidate()
                    self.saveImageToCustomAlbum(watermarkedImage)
                }
            }
        }
    }
    
    nonisolated func addWatermark(
        image: UIImage,
        location: CoreLocation.CLLocation,
        address: String,
        configuration: WatermarkConfiguration,
        mapSnapshot: UIImage?
    ) -> UIImage {
        let watermarkText = watermarkText(for: location, address: address, configuration: configuration)
        
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
        if configuration.showsLogo, let logo = UIImage(named: "nsra") {
            let logoSize: CGFloat = minDimension * 0.12
            let logoRect = CGRect(x: image.size.width - logoSize - textPadding, y: textPadding, width: logoSize, height: logoSize)
            logo.draw(in: logoRect, blendMode: .normal, alpha: 0.8)
        }

        if configuration.showsMiniMap, let mapSnapshot {
            let mapSize = CGSize(width: minDimension * 0.22, height: minDimension * 0.22)
            let mapRect = CGRect(
                x: image.size.width - mapSize.width - textPadding,
                y: image.size.height - backgroundHeight - mapSize.height - textPadding,
                width: mapSize.width,
                height: mapSize.height
            )

            let roundedPath = UIBezierPath(roundedRect: mapRect, cornerRadius: minDimension * 0.02)
            roundedPath.addClip()
            mapSnapshot.draw(in: mapRect)

            UIColor.white.withAlphaComponent(0.7).setStroke()
            roundedPath.lineWidth = 2
            roundedPath.stroke()
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
