import UIKit
import AVFoundation
import CoreLocation
import CoreMotion
import MapKit
import MediaPlayer
import Photos
import PhotosUI

class ViewController: UIViewController {
    struct WatermarkConfiguration {
        let showsCoordinates: Bool
        let showsAltitude: Bool
        let showsAccuracy: Bool
        let showsDate: Bool
        let showsAddress: Bool
        let showsLogo: Bool
        let showsMiniMap: Bool
    }
    
    // MARK: - Properties
    var captureSession: AVCaptureSession!
    var photoOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation?
    var address: String = "Cargando dirección..."

    let motionManager = CMMotionManager()
    var physicalOrientation: UIDeviceOrientation = .portrait

    var previewTimer: Timer?
    // Session Management
    let sessionQueue = DispatchQueue(label: "session queue")
    var videoDeviceInput: AVCaptureDeviceInput!
    
    // UI State
    var isGridVisible = false
    var flashMode: AVCaptureDevice.FlashMode = .auto
    var currentZoomFactor: CGFloat = 1.0
    var isControlsVisible = false
    var isOrientationLocked = false
    var lockedOrientation: UIDeviceOrientation?
    var lastKnownLevelAngle: CGFloat = 0
    var currentMapSnapshot: UIImage?
    var lastSnapshotLocation: CLLocation?
    var volumeObservation: NSKeyValueObservation?
    var isResettingVolume = false
    var lastSystemVolume = AVAudioSession.sharedInstance().outputVolume
    let customAlbumName = "NS TagCam"
    
    enum AspectRatio: String, CaseIterable {
        case ratio4_3 = "4:3"
        case ratio16_9 = "16:9"
        case ratio1_1 = "1:1"
    }
    var currentAspectRatio: AspectRatio = .ratio4_3
    
    // MARK: - UI Components
    let aspectRatioButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("4:3", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        button.tintColor = .white
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.cornerRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return button
    }()
    let controlsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    let orientationLockButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "lock.rotation"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let advancedControlsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        stack.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        stack.layer.cornerRadius = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        return stack
    }()
    
    let isoSlider: UISlider = {
        let slider = UISlider()
        slider.minimumTrackTintColor = .systemOrange
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        return slider
    }()
    
    let exposureSlider: UISlider = {
        let slider = UISlider()
        slider.minimumTrackTintColor = .systemYellow
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        return slider
    }()
    
    let focusSquare: UIView = {
        let view = UIView()
        view.layer.borderColor = UIColor.systemYellow.cgColor
        view.layer.borderWidth = 1.5
        view.backgroundColor = .clear
        view.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        view.alpha = 0
        return view
    }()
    
    let topBlurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        return view
    }()
    
    let captureButton: UIButton = {
        let button = UIButton(type: .custom)
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .thin)
        button.setImage(UIImage(systemName: "circle.inset.filled", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        imageView.layer.borderWidth = 1.5
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    let galleryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "photo.on.rectangle.angled"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let infoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "info.circle.fill"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let gridButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "grid"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let flashButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "bolt.badge.a.fill"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.rotate.fill"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "nsra"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    let controlStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    let gridView: GridView = {
        let view = GridView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    let zoomStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        stack.layer.cornerRadius = 22
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
        return stack
    }()
    
    let shutterView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.alpha = 0
        view.isUserInteractionEnabled = false
        return view
    }()
    let watermarkPreviewView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        return view
    }()
    let watermarkPreviewTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.text = "NS TagCam"
        return label
    }()
    let watermarkPreviewLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textColor = UIColor.white.withAlphaComponent(0.86)
        label.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        return label
    }()
    let watermarkPreviewDivider: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        return view
    }()
    let watermarkMapPreview: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        return imageView
    }()
    let horizonGuideView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    let horizonLineView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.9)
        view.layer.cornerRadius = 1.5
        return view
    }()
    let horizonCenterDot: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        view.layer.cornerRadius = 4
        return view
    }()
    let volumeCaptureView: MPVolumeView = {
        let view = MPVolumeView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0.01
        return view
    }()
    let coordinatesSwitch = UISwitch()
    let altitudeSwitch = UISwitch()
    let accuracySwitch = UISwitch()
    let dateSwitch = UISwitch()
    let addressSwitch = UISwitch()
    let logoSwitch = UISwitch()
    let miniMapSwitch = UISwitch()
    var hasPresentedStartupOverlay = false

    let startupOverlayView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 0.04, green: 0.07, blue: 0.11, alpha: 1)
        view.alpha = 0
        return view
    }()
    let startupCardView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 28
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        view.clipsToBounds = true
        return view
    }()
    let startupLogoView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "nsra"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    let startupTitleLabel: UILabel = {
        let label = UILabel()
        let baseFont = UIFont.systemFont(ofSize: 32, weight: .heavy)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "NS TagCam"
        label.textColor = .white
        label.font = UIFont(
            descriptor: baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor,
            size: 32
        )
        return label
    }()
    let startupSubtitleLabel: UILabel = {
        let label = UILabel()
        let baseFont = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Capture with tagged evidence"
        label.textColor = UIColor.white.withAlphaComponent(0.72)
        label.font = UIFont(
            descriptor: baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor,
            size: 14
        )
        return label
    }()

    var sharedLayoutConstraints: [NSLayoutConstraint] = []
    var portraitLayoutConstraints: [NSLayoutConstraint] = []
    var landscapeLayoutConstraints: [NSLayoutConstraint] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLocationManager()
        setupCamera()
        setupUI()
        setupGestures()
        loadLatestPhotoThumbnail()
        setupVolumeButtonCapture()
        setupMotionManager()
        updateWatermarkPreview()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupVolumeButtonCapture()
        requestSceneOrientationUpdate(for: effectiveOrientation())
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentStartupOverlayIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
        
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        volumeObservation?.invalidate()
        super.viewWillDisappear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        shutterView.frame = view.bounds
        updateAdaptiveLayout()
        updatePreviewLayerOrientation()
    }

    override var shouldAutorotate: Bool {
        !isOrientationLocked
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if isOrientationLocked, let lockedOrientation {
            switch lockedOrientation {
            case .landscapeLeft: return .landscapeRight
            case .landscapeRight: return .landscapeLeft
            case .portraitUpsideDown: return .portraitUpsideDown
            default: return .portrait
            }
        }

        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.previewLayer?.frame = self.view.bounds
            self.updateAdaptiveLayout()
            self.updatePreviewLayerOrientation()
        })
    }
}
