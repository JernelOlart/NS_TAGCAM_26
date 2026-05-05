import UIKit

extension ViewController: UIGestureRecognizerDelegate {
    func setupUI() {
        view.addSubview(gridView)
        view.addSubview(focusSquare)
        view.addSubview(topBlurView)
        view.addSubview(watermarkPreviewView)
        view.addSubview(horizonGuideView)
        view.addSubview(captureButton)
        view.addSubview(imageView)
        view.addSubview(galleryButton)
        view.addSubview(zoomStackView)
        view.addSubview(shutterView)
        view.addSubview(advancedControlsStack)
        view.addSubview(volumeCaptureView)
        view.addSubview(startupOverlayView)

        watermarkPreviewView.contentView.addSubview(watermarkPreviewTitleLabel)
        watermarkPreviewView.contentView.addSubview(watermarkPreviewDivider)
        watermarkPreviewView.contentView.addSubview(watermarkPreviewLabel)
        watermarkPreviewView.contentView.addSubview(watermarkMapPreview)
        watermarkPreviewView.contentView.addSubview(watermarkLogoPreview)
        horizonGuideView.addSubview(horizonLineView)
        horizonGuideView.addSubview(horizonCenterDot)
        startupOverlayView.addSubview(startupCardView)
        startupCardView.contentView.addSubview(startupLogoView)
        startupCardView.contentView.addSubview(startupTitleLabel)
        startupCardView.contentView.addSubview(startupSubtitleLabel)
        
        let isoIcon = UIImageView(image: UIImage(systemName: "camera.aperture"))
        isoIcon.tintColor = .white
        let expIcon = UIImageView(image: UIImage(systemName: "sun.max.fill"))
        expIcon.tintColor = .white
        
        let isoStack = UIStackView(arrangedSubviews: [isoIcon, isoSlider])
        isoStack.spacing = 10
        let expStack = UIStackView(arrangedSubviews: [expIcon, exposureSlider])
        expStack.spacing = 10
        
        advancedControlsStack.addArrangedSubview(isoStack)
        advancedControlsStack.addArrangedSubview(expStack)

        [logoImageView, flashButton, aspectRatioButton, gridButton, orientationLockButton, presetButton, switchCameraButton, controlsButton, infoButton]
            .forEach { controlStackView.addArrangedSubview($0) }
        topBlurView.contentView.addSubview(controlStackView)

        configureWatermarkSwitches()
        [
            makeSwitchRow(title: "Coordenadas", control: coordinatesSwitch),
            makeSwitchRow(title: "Altitud", control: altitudeSwitch),
            makeSwitchRow(title: "Precisión", control: accuracySwitch),
            makeSwitchRow(title: "Fecha", control: dateSwitch),
            makeSwitchRow(title: "Dirección", control: addressSwitch),
            makeSwitchRow(title: "Logo", control: logoSwitch),
            makeSwitchRow(title: "Mini mapa", control: miniMapSwitch)
        ].forEach { advancedControlsStack.addArrangedSubview($0) }
        
        sharedLayoutConstraints = [
            logoImageView.widthAnchor.constraint(equalToConstant: 30),
            logoImageView.heightAnchor.constraint(equalToConstant: 30),

            gridView.topAnchor.constraint(equalTo: view.topAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            horizonGuideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            horizonGuideView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            horizonGuideView.widthAnchor.constraint(equalToConstant: 160),
            horizonGuideView.heightAnchor.constraint(equalToConstant: 48),
            horizonLineView.centerXAnchor.constraint(equalTo: horizonGuideView.centerXAnchor),
            horizonLineView.centerYAnchor.constraint(equalTo: horizonGuideView.centerYAnchor),
            horizonLineView.widthAnchor.constraint(equalToConstant: 120),
            horizonLineView.heightAnchor.constraint(equalToConstant: 3),
            horizonCenterDot.centerXAnchor.constraint(equalTo: horizonGuideView.centerXAnchor),
            horizonCenterDot.centerYAnchor.constraint(equalTo: horizonGuideView.centerYAnchor),
            horizonCenterDot.widthAnchor.constraint(equalToConstant: 8),
            horizonCenterDot.heightAnchor.constraint(equalToConstant: 8),
            
            captureButton.widthAnchor.constraint(equalToConstant: 90),
            captureButton.heightAnchor.constraint(equalToConstant: 90),
            
            galleryButton.widthAnchor.constraint(equalToConstant: 44),
            galleryButton.heightAnchor.constraint(equalToConstant: 44),

            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),

            volumeCaptureView.widthAnchor.constraint(equalToConstant: 1),
            volumeCaptureView.heightAnchor.constraint(equalToConstant: 1),
            volumeCaptureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            volumeCaptureView.topAnchor.constraint(equalTo: view.topAnchor),

            startupOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            startupOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            startupOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            startupOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            startupCardView.centerXAnchor.constraint(equalTo: startupOverlayView.centerXAnchor),
            startupCardView.centerYAnchor.constraint(equalTo: startupOverlayView.centerYAnchor),
            startupCardView.leadingAnchor.constraint(greaterThanOrEqualTo: startupOverlayView.leadingAnchor, constant: 32),
            startupCardView.trailingAnchor.constraint(lessThanOrEqualTo: startupOverlayView.trailingAnchor, constant: -32),

            startupLogoView.topAnchor.constraint(equalTo: startupCardView.contentView.topAnchor, constant: 28),
            startupLogoView.centerXAnchor.constraint(equalTo: startupCardView.contentView.centerXAnchor),
            startupLogoView.widthAnchor.constraint(equalToConstant: 110),
            startupLogoView.heightAnchor.constraint(equalToConstant: 110),
            startupTitleLabel.topAnchor.constraint(equalTo: startupLogoView.bottomAnchor, constant: 18),
            startupTitleLabel.centerXAnchor.constraint(equalTo: startupCardView.contentView.centerXAnchor),
            startupSubtitleLabel.topAnchor.constraint(equalTo: startupTitleLabel.bottomAnchor, constant: 8),
            startupSubtitleLabel.centerXAnchor.constraint(equalTo: startupCardView.contentView.centerXAnchor),
            startupSubtitleLabel.bottomAnchor.constraint(equalTo: startupCardView.contentView.bottomAnchor, constant: -28)
        ]

        portraitLayoutConstraints = [
            topBlurView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            topBlurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topBlurView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            topBlurView.heightAnchor.constraint(equalToConstant: 60),

            controlStackView.leadingAnchor.constraint(equalTo: topBlurView.contentView.leadingAnchor, constant: 20),
            controlStackView.trailingAnchor.constraint(equalTo: topBlurView.contentView.trailingAnchor, constant: -20),
            controlStackView.centerYAnchor.constraint(equalTo: topBlurView.contentView.centerYAnchor),

            advancedControlsStack.topAnchor.constraint(equalTo: topBlurView.bottomAnchor, constant: 15),
            advancedControlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            advancedControlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            advancedControlsStack.heightAnchor.constraint(equalToConstant: 360),

            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            zoomStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            zoomStackView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -30),
            zoomStackView.heightAnchor.constraint(equalToConstant: 44),

            watermarkPreviewView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            watermarkPreviewView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            watermarkPreviewView.bottomAnchor.constraint(equalTo: zoomStackView.topAnchor, constant: -16),
            watermarkPreviewView.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
            watermarkPreviewTitleLabel.leadingAnchor.constraint(equalTo: watermarkPreviewView.contentView.leadingAnchor, constant: 14),
            watermarkPreviewTitleLabel.topAnchor.constraint(equalTo: watermarkPreviewView.contentView.topAnchor, constant: 10),
            watermarkPreviewDivider.leadingAnchor.constraint(equalTo: watermarkPreviewView.contentView.leadingAnchor, constant: 14),
            watermarkPreviewDivider.trailingAnchor.constraint(equalTo: watermarkPreviewView.contentView.trailingAnchor, constant: -14),
            watermarkPreviewDivider.topAnchor.constraint(equalTo: watermarkPreviewTitleLabel.bottomAnchor, constant: 8),
            watermarkPreviewDivider.heightAnchor.constraint(equalToConstant: 1),
            watermarkPreviewLabel.leadingAnchor.constraint(equalTo: watermarkPreviewView.contentView.leadingAnchor, constant: 14),
            watermarkPreviewLabel.topAnchor.constraint(equalTo: watermarkPreviewDivider.bottomAnchor, constant: 8),
            watermarkPreviewLabel.bottomAnchor.constraint(equalTo: watermarkPreviewView.contentView.bottomAnchor, constant: -12),
            watermarkMapPreview.trailingAnchor.constraint(equalTo: watermarkPreviewView.contentView.trailingAnchor, constant: -14),
            watermarkMapPreview.centerYAnchor.constraint(equalTo: watermarkPreviewView.contentView.centerYAnchor),
            watermarkMapPreview.widthAnchor.constraint(equalToConstant: 68),
            watermarkMapPreview.heightAnchor.constraint(equalToConstant: 68),
            watermarkPreviewLabel.trailingAnchor.constraint(equalTo: watermarkMapPreview.leadingAnchor, constant: -10),

            watermarkLogoPreview.trailingAnchor.constraint(equalTo: watermarkPreviewView.contentView.trailingAnchor, constant: -14),
            watermarkLogoPreview.topAnchor.constraint(equalTo: watermarkPreviewView.contentView.topAnchor, constant: 10),
            watermarkLogoPreview.widthAnchor.constraint(equalToConstant: 24),
            watermarkLogoPreview.heightAnchor.constraint(equalToConstant: 24),


            imageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            imageView.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            galleryButton.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 14),
            galleryButton.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
        ]

        landscapeLayoutConstraints = [
            topBlurView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            topBlurView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            topBlurView.widthAnchor.constraint(equalToConstant: 64),
            topBlurView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -40),

            controlStackView.topAnchor.constraint(equalTo: topBlurView.contentView.topAnchor, constant: 18),
            controlStackView.bottomAnchor.constraint(equalTo: topBlurView.contentView.bottomAnchor, constant: -18),
            controlStackView.centerXAnchor.constraint(equalTo: topBlurView.contentView.centerXAnchor),

            advancedControlsStack.leadingAnchor.constraint(equalTo: topBlurView.trailingAnchor, constant: 16),
            advancedControlsStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            advancedControlsStack.widthAnchor.constraint(equalToConstant: 220),
            advancedControlsStack.heightAnchor.constraint(equalToConstant: 360),
            advancedControlsStack.trailingAnchor.constraint(lessThanOrEqualTo: zoomStackView.leadingAnchor, constant: -20),

            captureButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            captureButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            zoomStackView.trailingAnchor.constraint(equalTo: captureButton.leadingAnchor, constant: -24),
            zoomStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            zoomStackView.heightAnchor.constraint(equalToConstant: 44),

            watermarkPreviewView.leadingAnchor.constraint(equalTo: topBlurView.trailingAnchor, constant: 16),
            watermarkPreviewView.trailingAnchor.constraint(equalTo: captureButton.leadingAnchor, constant: -20),
            watermarkPreviewView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            watermarkPreviewView.heightAnchor.constraint(greaterThanOrEqualToConstant: 88),
            watermarkPreviewTitleLabel.leadingAnchor.constraint(equalTo: watermarkPreviewView.contentView.leadingAnchor, constant: 14),
            watermarkPreviewTitleLabel.topAnchor.constraint(equalTo: watermarkPreviewView.contentView.topAnchor, constant: 10),
            watermarkPreviewDivider.leadingAnchor.constraint(equalTo: watermarkPreviewView.contentView.leadingAnchor, constant: 14),
            watermarkPreviewDivider.trailingAnchor.constraint(equalTo: watermarkPreviewView.contentView.trailingAnchor, constant: -14),
            watermarkPreviewDivider.topAnchor.constraint(equalTo: watermarkPreviewTitleLabel.bottomAnchor, constant: 8),
            watermarkPreviewDivider.heightAnchor.constraint(equalToConstant: 1),
            watermarkPreviewLabel.leadingAnchor.constraint(equalTo: watermarkPreviewView.contentView.leadingAnchor, constant: 14),
            watermarkPreviewLabel.topAnchor.constraint(equalTo: watermarkPreviewDivider.bottomAnchor, constant: 8),
            watermarkPreviewLabel.bottomAnchor.constraint(equalTo: watermarkPreviewView.contentView.bottomAnchor, constant: -12),
            watermarkMapPreview.trailingAnchor.constraint(equalTo: watermarkPreviewView.contentView.trailingAnchor, constant: -14),
            watermarkMapPreview.centerYAnchor.constraint(equalTo: watermarkPreviewView.contentView.centerYAnchor),
            watermarkMapPreview.widthAnchor.constraint(equalToConstant: 68),
            watermarkMapPreview.heightAnchor.constraint(equalToConstant: 68),
            watermarkPreviewLabel.trailingAnchor.constraint(equalTo: watermarkMapPreview.leadingAnchor, constant: -10),

            watermarkLogoPreview.trailingAnchor.constraint(equalTo: watermarkPreviewView.contentView.trailingAnchor, constant: -14),
            watermarkLogoPreview.topAnchor.constraint(equalTo: watermarkPreviewView.contentView.topAnchor, constant: 10),
            watermarkLogoPreview.widthAnchor.constraint(equalToConstant: 24),
            watermarkLogoPreview.heightAnchor.constraint(equalToConstant: 24),


            imageView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            galleryButton.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 14),
            galleryButton.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
        ]

        NSLayoutConstraint.activate(sharedLayoutConstraints)
        updateAdaptiveLayout()
        focusSquare.layer.zPosition = 1
        shutterView.layer.zPosition = 2
        gridView.layer.zPosition = 3
        horizonGuideView.layer.zPosition = 4
        topBlurView.layer.zPosition = 5
        advancedControlsStack.layer.zPosition = 5
        watermarkPreviewView.layer.zPosition = 5
        captureButton.layer.zPosition = 5
        zoomStackView.layer.zPosition = 5
        imageView.layer.zPosition = 5
        galleryButton.layer.zPosition = 5
        startupOverlayView.layer.zPosition = 20
        
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        infoButton.addTarget(self, action: #selector(showInfoAlert), for: .touchUpInside)
        gridButton.addTarget(self, action: #selector(toggleGrid), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        orientationLockButton.addTarget(self, action: #selector(toggleOrientationLock), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        controlsButton.addTarget(self, action: #selector(toggleControls), for: .touchUpInside)
        galleryButton.addTarget(self, action: #selector(openGallery), for: .touchUpInside)
        isoSlider.addTarget(self, action: #selector(isoChanged(_:)), for: .valueChanged)
        exposureSlider.addTarget(self, action: #selector(exposureChanged(_:)), for: .valueChanged)
        aspectRatioButton.addTarget(self, action: #selector(toggleAspectRatio), for: .touchUpInside)
        presetButton.addTarget(self, action: #selector(showPresetMenu), for: .touchUpInside)

        let galleryTapGesture = UITapGestureRecognizer(target: self, action: #selector(openGallery))
        imageView.addGestureRecognizer(galleryTapGesture)
        
        let zoomLevels: [CGFloat] = [0.5, 1.0, 2.0, 3.0]
        for (index, zoom) in zoomLevels.enumerated() {
            let button = UIButton(type: .system)
            let title = zoom == 0.5 ? ".5" : "\(Int(zoom))"
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            button.tintColor = index == 1 ? .systemYellow : .white
            button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            button.layer.cornerRadius = 16
            button.tag = index
            
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
            
            button.addTarget(self, action: #selector(zoomButtonTapped(_:)), for: .touchUpInside)
            zoomStackView.addArrangedSubview(button)
        }
    }

    func updateAdaptiveLayout(animated: Bool = false) {
        guard !sharedLayoutConstraints.isEmpty else { return }

        let isLandscape = physicalOrientation.isLandscape || view.bounds.width > view.bounds.height

        NSLayoutConstraint.deactivate(portraitLayoutConstraints + landscapeLayoutConstraints)
        NSLayoutConstraint.activate(isLandscape ? landscapeLayoutConstraints : portraitLayoutConstraints)

        controlStackView.axis = isLandscape ? .vertical : .horizontal
        controlStackView.spacing = isLandscape ? 18 : 14
        topBlurView.layer.cornerRadius = isLandscape ? 28 : 20
        imageView.layer.cornerRadius = isLandscape ? 16 : 12

        let updates = {
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: updates)
        } else {
            updates()
        }
    }
    
    func setupGestures() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        view.addGestureRecognizer(pinchGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    private func configureWatermarkSwitches() {
        [coordinatesSwitch, altitudeSwitch, accuracySwitch, dateSwitch, addressSwitch, logoSwitch, miniMapSwitch].forEach {
            $0.onTintColor = .systemYellow
            $0.isOn = true
            $0.addTarget(self, action: #selector(watermarkSwitchChanged(_:)), for: .valueChanged)
        }
    }

    private func makeSwitchRow(title: String, control: UISwitch) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .semibold)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [label, spacer, control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return row
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let protectedViews: [UIView] = [
            topBlurView,
            advancedControlsStack,
            watermarkPreviewView,
            captureButton,
            imageView,
            galleryButton,
            zoomStackView
        ]

        return !protectedViews.contains { candidate in
            touch.view?.isDescendant(of: candidate) == true
        }
    }

    func presentStartupOverlayIfNeeded() {
        guard !hasPresentedStartupOverlay else { return }
        hasPresentedStartupOverlay = true

        startupOverlayView.isHidden = false
        startupOverlayView.alpha = 1
        startupCardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        startupCardView.alpha = 0.94
        startupLogoView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)

        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.4,
            options: [.curveEaseOut]
        ) {
            self.startupCardView.transform = .identity
            self.startupLogoView.transform = .identity
        }

        UIView.animateKeyframes(withDuration: 0.9, delay: 0.08, options: [.calculationModeCubic]) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.45) {
                self.startupCardView.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
                self.startupLogoView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.45, relativeDuration: 0.3) {
                self.startupCardView.transform = .identity
                self.startupLogoView.transform = .identity
            }
        }

        UIView.animate(withDuration: 0.28, delay: 1.0, options: [.curveEaseInOut]) {
            self.startupOverlayView.alpha = 0
            self.startupCardView.alpha = 0
            self.startupCardView.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
        } completion: { _ in
            self.startupOverlayView.isHidden = true
        }
    }
}
