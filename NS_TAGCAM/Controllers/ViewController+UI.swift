import UIKit

extension ViewController {
    func setupUI() {
        view.addSubview(gridView)
        view.addSubview(topBlurView)
        view.addSubview(captureButton)
        view.addSubview(imageView)
        view.addSubview(logoImageView)
        view.addSubview(zoomSlider)
        view.addSubview(shutterView)
        view.addSubview(focusSquare)
        view.addSubview(advancedControlsStack)
        
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
        
        let controlStack = UIStackView(arrangedSubviews: [flashButton, gridButton, switchCameraButton, controlsButton, infoButton])
        controlStack.axis = .horizontal
        controlStack.distribution = .equalSpacing
        controlStack.alignment = .center
        controlStack.spacing = 24
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        topBlurView.contentView.addSubview(controlStack)
        
        NSLayoutConstraint.activate([
            topBlurView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            topBlurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topBlurView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            topBlurView.heightAnchor.constraint(equalToConstant: 60),
            
            controlStack.leadingAnchor.constraint(equalTo: topBlurView.contentView.leadingAnchor, constant: 20),
            controlStack.trailingAnchor.constraint(equalTo: topBlurView.contentView.trailingAnchor, constant: -20),
            controlStack.centerYAnchor.constraint(equalTo: topBlurView.contentView.centerYAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: topBlurView.bottomAnchor, constant: 10),
            logoImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logoImageView.widthAnchor.constraint(equalToConstant: 20),
            logoImageView.heightAnchor.constraint(equalToConstant: 20),
            
            advancedControlsStack.topAnchor.constraint(equalTo: topBlurView.bottomAnchor, constant: 15),
            advancedControlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            advancedControlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            advancedControlsStack.heightAnchor.constraint(equalToConstant: 100),
            
            gridView.topAnchor.constraint(equalTo: view.topAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            captureButton.widthAnchor.constraint(equalToConstant: 90),
            captureButton.heightAnchor.constraint(equalToConstant: 90),
            
            zoomSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            zoomSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            zoomSlider.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -40),
            
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            imageView.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        infoButton.addTarget(self, action: #selector(showInfoAlert), for: .touchUpInside)
        gridButton.addTarget(self, action: #selector(toggleGrid), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        zoomSlider.addTarget(self, action: #selector(zoomSliderChanged(_:)), for: .valueChanged)
        controlsButton.addTarget(self, action: #selector(toggleControls), for: .touchUpInside)
        isoSlider.addTarget(self, action: #selector(isoChanged(_:)), for: .valueChanged)
        exposureSlider.addTarget(self, action: #selector(exposureChanged(_:)), for: .valueChanged)
    }
    
    func setupGestures() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(_:)))
        view.addGestureRecognizer(tapGesture)
    }
}
