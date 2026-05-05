import UIKit
import Photos

class GalleryViewController: UIViewController {
    private var assets: PHFetchResult<PHAsset>!
    private let albumName = "NS TagCam"
    private var isSelectionMode = false
    private var selectedAssets: [PHAsset] = []
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "No hay fotos en NS TagCam"
        label.textColor = .lightGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchAssets()
    }
    
    private func setupUI() {
        title = "NS TagCam Gallery"
        view.backgroundColor = .black
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemYellow
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Seleccionar", style: .plain, target: self, action: #selector(toggleSelectionMode))
        
        view.addSubview(collectionView)
        view.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    private func fetchAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let collection = collections.firstObject {
            let assetOptions = PHFetchOptions()
            assetOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            assets = PHAsset.fetchAssets(in: collection, options: assetOptions)
        } else {
            // Fallback or empty
            assets = PHFetchResult<PHAsset>()
        }
        
        emptyLabel.isHidden = assets.count > 0
        collectionView.reloadData()
    }
    
    @objc private func done() {
        dismiss(animated: true)
    }
}

extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let asset = assets.object(at: indexPath.item)
        let isSelected = selectedAssets.contains(asset)
        cell.configure(with: asset, isSelected: isSelected, isSelectionMode: isSelectionMode)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 4) / 3
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = assets.object(at: indexPath.item)
        
        if isSelectionMode {
            if let index = selectedAssets.firstIndex(of: asset) {
                selectedAssets.remove(at: index)
            } else {
                selectedAssets.append(asset)
            }
            collectionView.reloadItems(at: [indexPath])
            updateSelectionTitle()
            return
        }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { [weak self] image, _ in
            guard let self, let image = image else { return }
            DispatchQueue.main.async {
                self.showPhotoDetail(image: image)
            }
        }
    }
    
    private func showPhotoDetail(image: UIImage) {
        let vc = UIViewController()
        vc.view.backgroundColor = .black
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFit
        iv.frame = vc.view.bounds
        iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.addSubview(iv)
        
        let shareBtn = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(sharePhoto(_:)))
        vc.navigationItem.rightBarButtonItem = shareBtn
        
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func sharePhoto(_ sender: UIBarButtonItem) {
        guard let vc = navigationController?.topViewController,
              let iv = vc.view.subviews.compactMap({ $0 as? UIImageView }).first,
              let image = iv.image else { return }
        
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        present(activityVC, animated: true)
    }

    @objc private func toggleSelectionMode() {
        isSelectionMode.toggle()
        selectedAssets.removeAll()
        navigationItem.leftBarButtonItem?.title = isSelectionMode ? "Cancelar" : "Seleccionar"
        
        if isSelectionMode {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Exportar PDF", style: .done, target: self, action: #selector(exportPDF))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
            title = "NS TagCam Gallery"
        }
        
        collectionView.reloadData()
    }

    private func updateSelectionTitle() {
        if isSelectionMode {
            title = "\(selectedAssets.count) seleccionadas"
        }
    }

    @objc private func exportPDF() {
        guard !selectedAssets.isEmpty else { return }
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 612, height: 792), nil)
        
        let imageOptions = PHImageRequestOptions()
        imageOptions.isSynchronous = true
        imageOptions.deliveryMode = .highQualityFormat
        
        for asset in selectedAssets {
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1200, height: 1600), contentMode: .aspectFit, options: imageOptions) { image, _ in
                guard let image = image else { return }
                UIGraphicsBeginPDFPageWithInfo(CGRect(x: 0, y: 0, width: 612, height: 792), nil)
                
                // Draw title
                let title = "NS TagCam - Reporte de Evidencia"
                let titleAttr = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18)]
                title.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttr)
                
                // Draw image
                let imageRect = CGRect(x: 50, y: 100, width: 512, height: 600)
                image.draw(in: imageRect)
                
                // Draw metadata
                let metadata = "Fecha: \(asset.creationDate?.description ?? "N/A")\nID: \(asset.localIdentifier)"
                let metaAttr = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]
                metadata.draw(in: CGRect(x: 50, y: 710, width: 512, height: 50), withAttributes: metaAttr)
            }
        }
        
        UIGraphicsEndPDFContext()
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("NS_TagCam_Report.pdf")
        pdfData.write(to: tempURL, atomically: true)
        
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        present(activityVC, animated: true)
    }
}

class PhotoCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()
    
    private let selectionOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.4)
        view.isHidden = true
        return view
    }()
    
    private let checkmarkIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        iv.tintColor = .systemYellow
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(selectionOverlay)
        contentView.addSubview(checkmarkIcon)
        
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        selectionOverlay.frame = contentView.bounds
        selectionOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        NSLayoutConstraint.activate([
            checkmarkIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkmarkIcon.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            checkmarkIcon.widthAnchor.constraint(equalToConstant: 24),
            checkmarkIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with asset: PHAsset, isSelected: Bool, isSelectionMode: Bool) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        let scale = UIScreen.main.scale
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            self?.imageView.image = image
        }
        
        selectionOverlay.isHidden = !isSelected
        checkmarkIcon.isHidden = !isSelected
    }
}
