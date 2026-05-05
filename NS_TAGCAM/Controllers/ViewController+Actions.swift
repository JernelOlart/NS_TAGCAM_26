import UIKit
import AVFoundation
import MapKit
import MediaPlayer
import Photos
import PhotosUI

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
        guard isPointAvailableForFocus(touchPoint) else { return }
        
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
            focusSquare.layer.borderColor = UIColor.systemYellow.withAlphaComponent(0.95).cgColor
            focusSquare.alpha = 1
            focusSquare.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
            
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut], animations: {
                self.focusSquare.transform = .identity
            }) { _ in
                UIView.animate(withDuration: 0.22, delay: 0.55, options: [.curveEaseInOut], animations: {
                    self.focusSquare.alpha = 0
                })
            }
            
            if isControlsVisible {
                updateSlidersFromCamera()
            }
            
        } catch { print(error) }
    }

    func isPointAvailableForFocus(_ point: CGPoint) -> Bool {
        guard focusInteractionRect().contains(point) else { return false }

        let blockedViews: [UIView] = [
            topBlurView,
            advancedControlsStack,
            watermarkPreviewView,
            captureButton,
            imageView,
            galleryButton,
            zoomStackView
        ]

        return !blockedViews.contains { blockedView in
            !blockedView.isHidden && blockedView.alpha > 0.01 && blockedView.frame.contains(point)
        }
    }

    func focusInteractionRect() -> CGRect {
        var rect = view.bounds.insetBy(dx: 24, dy: 24)

        let topLimit = max(
            topBlurView.frame.maxY,
            advancedControlsStack.isHidden ? 0 : advancedControlsStack.frame.maxY
        )
        if topLimit > 0 {
            rect.origin.y = max(rect.origin.y, topLimit + 12)
        }

        if !watermarkPreviewView.isHidden, watermarkPreviewView.alpha > 0.01 {
            rect.size.height = min(rect.maxY, watermarkPreviewView.frame.minY - 12) - rect.origin.y
        } else if zoomStackView.alpha > 0.01 {
            rect.size.height = min(rect.maxY, zoomStackView.frame.minY - 12) - rect.origin.y
        }

        if effectiveOrientation().isLandscape {
            rect.origin.x = max(rect.origin.x, topBlurView.frame.maxX + 12)
            rect.size.width = min(rect.maxX, zoomStackView.frame.minX - 12) - rect.origin.x
        }

        return rect.standardized
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
    
    @objc func toggleAspectRatio() {
        feedbackGenerator()
        let allRatios = AspectRatio.allCases
        if let currentIndex = allRatios.firstIndex(of: currentAspectRatio) {
            let nextIndex = (currentIndex + 1) % allRatios.count
            currentAspectRatio = allRatios[nextIndex]
            aspectRatioButton.setTitle(currentAspectRatio.rawValue, for: .normal)
        }
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

    @objc func openPhotoLibrary() {
        feedbackGenerator()

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc func toggleOrientationLock() {
        feedbackGenerator()
        isOrientationLocked.toggle()
        lockedOrientation = isOrientationLocked ? physicalOrientation : nil
        orientationLockButton.tintColor = isOrientationLocked ? .systemYellow : .white
        orientationLockButton.setImage(
            UIImage(systemName: isOrientationLocked ? "lock.rotation" : "lock.open.rotation"),
            for: .normal
        )
        setNeedsUpdateOfSupportedInterfaceOrientations()
        requestSceneOrientationUpdate(for: effectiveOrientation())
        updatePreviewLayerOrientation()
    }

    @objc func watermarkSwitchChanged(_ sender: UISwitch) {
        updateWatermarkPreview()
        if sender == miniMapSwitch, miniMapSwitch.isOn, let location = currentLocation {
            refreshMapSnapshot(for: location)
        }
    }

    func loadLatestPhotoThumbnail() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            fetchLatestPhotoThumbnail()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                guard let self else { return }
                if status == .authorized || status == .limited {
                    self.fetchLatestPhotoThumbnail()
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private func fetchLatestPhotoThumbnail() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let asset = assets.firstObject else { return }

        let scale = view.window?.windowScene?.screen.scale ?? traitCollection.displayScale
        let targetSize = CGSize(width: 180 * scale, height: 180 * scale)
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact
        requestOptions.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: requestOptions
        ) { [weak self] image, _ in
            guard let self, let image else { return }
            DispatchQueue.main.async {
                self.imageView.image = image
                self.imageView.alpha = 1
                self.imageView.transform = .identity
            }
        }
    }

    func currentWatermarkConfiguration() -> WatermarkConfiguration {
        WatermarkConfiguration(
            showsCoordinates: coordinatesSwitch.isOn,
            showsAltitude: altitudeSwitch.isOn,
            showsAccuracy: accuracySwitch.isOn,
            showsDate: dateSwitch.isOn,
            showsAddress: addressSwitch.isOn,
            showsLogo: logoSwitch.isOn,
            showsMiniMap: miniMapSwitch.isOn
        )
    }

    func updateWatermarkPreview() {
        let location = currentLocation ?? CLLocation()
        let config = currentWatermarkConfiguration()
        watermarkPreviewTitleLabel.text = config.showsMiniMap ? "NS TagCam · Geo" : "NS TagCam"
        watermarkPreviewLabel.attributedText = watermarkPreviewAttributedText(
            for: location,
            address: address,
            configuration: config
        )
        watermarkMapPreview.image = currentMapSnapshot
        watermarkMapPreview.isHidden = !config.showsMiniMap
        watermarkPreviewDivider.isHidden = false
    }

    nonisolated func watermarkText(for location: CLLocation, address: String, configuration: WatermarkConfiguration) -> String {
        var lines: [String] = []

        if configuration.showsCoordinates {
            lines.append(String(format: "Lat: %.6f  Lon: %.6f", location.coordinate.latitude, location.coordinate.longitude))
        }
        if configuration.showsAltitude {
            lines.append(String(format: "Altitud: %.1f m", location.altitude))
        }
        if configuration.showsAccuracy {
            lines.append(String(format: "Precisión: %.1f m", location.horizontalAccuracy))
        }
        if configuration.showsDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            lines.append("Fecha: \(formatter.string(from: Date()))")
        }
        if configuration.showsAddress {
            lines.append("Dirección: \(address)")
        }

        if lines.isEmpty {
            lines.append("NS TagCam")
        }

        return lines.joined(separator: "\n")
    }

    nonisolated func watermarkPreviewAttributedText(
        for location: CLLocation,
        address: String,
        configuration: WatermarkConfiguration
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        let fullText = NSMutableAttributedString()

        func append(_ title: String, _ value: String) {
            if !fullText.string.isEmpty {
                fullText.append(NSAttributedString(string: "\n"))
            }

            fullText.append(
                NSAttributedString(
                    string: "\(title) ",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.62),
                        .paragraphStyle: paragraph
                    ]
                )
            )
            fullText.append(
                NSAttributedString(
                    string: value,
                    attributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .medium),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                        .paragraphStyle: paragraph
                    ]
                )
            )
        }

        if configuration.showsCoordinates {
            append("GPS", String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude))
        }
        if configuration.showsAltitude {
            append("ALT", String(format: "%.1f m", location.altitude))
        }
        if configuration.showsAccuracy {
            append("ACC", String(format: "%.1f m", location.horizontalAccuracy))
        }
        if configuration.showsDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            append("TIME", formatter.string(from: Date()))
        }
        if configuration.showsAddress {
            let compactAddress = address
                .replacingOccurrences(of: ", ", with: "\n")
                .split(separator: "\n")
                .prefix(2)
                .joined(separator: " · ")
            append("ADDR", compactAddress.isEmpty ? "Sin dirección" : compactAddress)
        }

        if fullText.string.isEmpty {
            append("READY", "Etiqueta activa")
        }

        return fullText
    }

    func refreshMapSnapshot(for location: CLLocation) {
        guard miniMapSwitch.isOn else {
            currentMapSnapshot = nil
            updateWatermarkPreview()
            return
        }

        if let lastSnapshotLocation, lastSnapshotLocation.distance(from: location) < 20 {
            updateWatermarkPreview()
            return
        }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 220, longitudinalMeters: 220)
        options.size = CGSize(width: 180, height: 180)
        options.scale = view.window?.windowScene?.screen.scale ?? traitCollection.displayScale
        options.showsBuildings = true
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { [weak self] snapshot, error in
            guard let self, let snapshot, error == nil else { return }

            let renderedImage = UIGraphicsImageRenderer(size: options.size).image { _ in
                snapshot.image.draw(at: .zero)

                let point = snapshot.point(for: location.coordinate)
                let pinBounds = CGRect(x: point.x - 9, y: point.y - 18, width: 18, height: 18)
                let pin = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
                pin?.draw(in: pinBounds)
            }

            DispatchQueue.main.async {
                self.lastSnapshotLocation = location
                self.currentMapSnapshot = renderedImage
                self.updateWatermarkPreview()
            }
        }
    }

    func setupVolumeButtonCapture() {
        volumeObservation?.invalidate()

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        lastSystemVolume = AVAudioSession.sharedInstance().outputVolume
        volumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
            guard let self,
                  let newValue = change.newValue,
                  let oldValue = change.oldValue,
                  newValue != oldValue
            else { return }

            DispatchQueue.main.async {
                if self.isResettingVolume {
                    self.isResettingVolume = false
                    return
                }

                self.capturePhoto()
                self.resetSystemVolume(to: oldValue)
            }
        }
    }

    private func resetSystemVolume(to value: Float) {
        guard let slider = volumeCaptureView.subviews.compactMap({ $0 as? UISlider }).first else { return }
        isResettingVolume = true
        slider.value = value
        slider.sendActions(for: .valueChanged)
        lastSystemVolume = value
    }

    func saveImageToCustomAlbum(_ image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                guard let self, status == .authorized || status == .limited else { return }
                self.saveImageToCustomAlbum(image)
            }
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.95) else { return }
        ensureCustomAlbum { [weak self] collection in
            guard let self, let collection else { return }

            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let assetRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                assetRequest.addResource(with: .photo, data: imageData, options: options)
                placeholder = assetRequest.placeholderForCreatedAsset

                if let albumChangeRequest = PHAssetCollectionChangeRequest(for: collection),
                   let placeholder {
                    albumChangeRequest.addAssets([placeholder] as NSArray)
                }
            }) { [weak self] success, error in
                if let error {
                    print("Album save error: \(error)")
                }
                guard success else { return }
                self?.loadLatestPhotoThumbnail()
            }
        }
    }

    private func ensureCustomAlbum(completion: @escaping (PHAssetCollection?) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", customAlbumName)

        if let existingAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions).firstObject {
            completion(existingAlbum)
            return
        }

        var albumPlaceholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.customAlbumName)
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }) { success, error in
            if let error {
                print("Album creation error: \(error)")
            }

            guard success, let albumPlaceholder else {
                completion(nil)
                return
            }

            let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumPlaceholder.localIdentifier],
                options: nil
            ).firstObject
            completion(collection)
        }
    }
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }
        guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self, error == nil, let image = object as? UIImage else { return }

            Task { @MainActor in
                self.imageView.image = image
                self.imageView.alpha = 1
                self.imageView.transform = .identity
            }
        }
    }
}
