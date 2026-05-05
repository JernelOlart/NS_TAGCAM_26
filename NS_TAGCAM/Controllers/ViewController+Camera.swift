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
                    mapSnapshot: mapSnapshot,
                    preset: self.currentPreset
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
        mapSnapshot: UIImage?,
        preset: WatermarkPreset
    ) -> UIImage {
        let minDimension = min(image.size.width, image.size.height)
        let textPadding: CGFloat = minDimension * 0.04
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        let context = UIGraphicsGetCurrentContext()
        
        // 1. Prepare Text and Attributes based on Preset
        let watermarkText = watermarkText(for: location, address: address, configuration: configuration) // We should probably have a preset-specific watermark text function too, but let's use the one we have for now or refine it.
        
        // Actually, let's use a more localized rendering logic for each preset
        switch preset {
        case .compact:
            renderCompactWatermark(image: image, location: location, minDimension: minDimension, padding: textPadding)
        case .technical:
            renderTechnicalWatermark(image: image, location: location, address: address, config: configuration, map: mapSnapshot, minDimension: minDimension, padding: textPadding)
        case .judicial:
            renderJudicialWatermark(image: image, location: location, address: address, minDimension: minDimension, padding: textPadding)
        case .minimalist:
            renderMinimalistWatermark(image: image, location: location, minDimension: minDimension, padding: textPadding)
        }
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? image
    }

    private nonisolated func renderCompactWatermark(image: UIImage, location: CoreLocation.CLLocation, minDimension: CGFloat, padding: CGFloat) {
        let fontSize = minDimension * 0.035
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let text = "NS TagCam | \(formatter.string(from: Date())) | \(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))"
        
        let size = text.size(withAttributes: attributes)
        let rect = CGRect(x: padding, y: image.size.height - size.height - padding, width: size.width, height: size.height)
        
        UIColor.black.withAlphaComponent(0.4).setFill()
        UIRectFill(rect.insetBy(dx: -4, dy: -2))
        text.draw(in: rect, withAttributes: attributes)
    }

    private nonisolated func renderTechnicalWatermark(image: UIImage, location: CoreLocation.CLLocation, address: String, config: WatermarkConfiguration, map: UIImage?, minDimension: CGFloat, padding: CGFloat) {
        let fontSize = minDimension * 0.028
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        
        var lines: [String] = []
        lines.append("NS TAGCAM TECHNICAL REPORT")
        lines.append("LAT: \(String(format: "%.6f", location.coordinate.latitude))")
        lines.append("LON: \(String(format: "%.6f", location.coordinate.longitude))")
        lines.append("ALT: \(String(format: "%.1f m", location.altitude)) ACC: \(String(format: "%.1f m", location.horizontalAccuracy))")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        lines.append("TIME: \(formatter.string(from: Date()))")
        
        if !address.isEmpty {
            lines.append("ADDR: \(address)")
        }
        
        let text = lines.joined(separator: "\n")
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let rect = attributedString.boundingRect(with: CGSize(width: image.size.width - padding * 2, height: 1000), options: .usesLineFragmentOrigin, context: nil)
        
        let bgRect = CGRect(x: 0, y: image.size.height - rect.height - padding * 2, width: image.size.width, height: rect.height + padding * 2)
        UIColor.black.withAlphaComponent(0.6).setFill()
        UIRectFill(bgRect)
        
        text.draw(in: CGRect(x: padding, y: bgRect.origin.y + padding, width: rect.width, height: rect.height), withAttributes: attributes)
        
        if let map = map, config.showsMiniMap {
            let mapSize = minDimension * 0.25
            let mapRect = CGRect(x: image.size.width - mapSize - padding, y: bgRect.origin.y - mapSize - padding, width: mapSize, height: mapSize)
            let path = UIBezierPath(roundedRect: mapRect, cornerRadius: minDimension * 0.02)
            path.addClip()
            map.draw(in: mapRect)
            UIColor.white.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    private nonisolated func renderJudicialWatermark(image: UIImage, location: CoreLocation.CLLocation, address: String, minDimension: CGFloat, padding: CGFloat) {
        let fontSize = minDimension * 0.03
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize * 1.2, weight: .black),
            .foregroundColor: UIColor.systemYellow
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let title = "EVIDENCIA DOCUMENTAL - NS TAGCAM"
        let ref = "REF: \(Int(Date().timeIntervalSince1970))"
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, dd 'de' MMMM 'de' yyyy, HH:mm:ss"
        let dateStr = formatter.string(from: Date())
        
        let locationStr = "COORD: \(String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)) | ALT: \(Int(location.altitude))m"
        
        let bgHeight = minDimension * 0.22
        let bgRect = CGRect(x: 0, y: image.size.height - bgHeight, width: image.size.width, height: bgHeight)
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.black.withAlphaComponent(0.85).cgColor)
        context?.fill(bgRect)
        
        // Draw yellow accent line
        context?.setFillColor(UIColor.systemYellow.cgColor)
        context?.fill(CGRect(x: 0, y: bgRect.origin.y, width: image.size.width, height: 4))
        
        title.draw(at: CGPoint(x: padding, y: bgRect.origin.y + padding), withAttributes: titleAttributes)
        ref.draw(at: CGPoint(x: image.size.width - ref.size(withAttributes: bodyAttributes).width - padding, y: bgRect.origin.y + padding), withAttributes: bodyAttributes)
        dateStr.draw(at: CGPoint(x: padding, y: bgRect.origin.y + padding + fontSize * 1.5), withAttributes: bodyAttributes)
        locationStr.draw(at: CGPoint(x: padding, y: bgRect.origin.y + padding + fontSize * 3.0), withAttributes: bodyAttributes)
        
        if let logo = UIImage(named: "nsra") {
            let logoSize = bgHeight * 0.6
            logo.draw(in: CGRect(x: image.size.width - logoSize - padding, y: bgRect.origin.y + (bgHeight - logoSize) / 2, width: logoSize, height: logoSize), blendMode: .normal, alpha: 0.5)
        }
    }

    private nonisolated func renderMinimalistWatermark(image: UIImage, location: CoreLocation.CLLocation, minDimension: CGFloat, padding: CGFloat) {
        let fontSize = minDimension * 0.025
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .light),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy HH:mm"
        let text = "\(formatter.string(from: Date())) | \(String(format: "%.3f, %.3f", location.coordinate.latitude, location.coordinate.longitude))"
        
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: image.size.width - size.width - padding, y: image.size.height - size.height - padding), withAttributes: attributes)
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
