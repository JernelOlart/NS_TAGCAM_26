import UIKit
import AVFoundation
import CoreLocation
import CoreMotion

class ViewController: UIViewController {
    
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
    let geocoder = CLGeocoder()
    
    // Session Management
    let sessionQueue = DispatchQueue(label: "session queue")
    var videoDeviceInput: AVCaptureDeviceInput!
    
    // UI State
    var isGridVisible = false
    var flashMode: AVCaptureDevice.FlashMode = .auto
    var currentZoomFactor: CGFloat = 1.0
    var isControlsVisible = false
    
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
    
    let advancedControlsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.distribution = .fillEqually
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
        imageView.isHidden = true
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        imageView.layer.borderWidth = 1.5
        return imageView
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
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLocationManager()
        setupCamera()
        setupUI()
        setupGestures()
        setupMotionManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
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
        super.viewWillDisappear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        shutterView.frame = view.bounds
        updatePreviewLayerOrientation()
    }
}
