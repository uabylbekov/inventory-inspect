import SwiftUI

enum ImageSource {
    case local(PlatformImage)
    case remote(URL)
}

struct FullScreenImageView: View {
    let image: ImageSource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
#if os(iOS)
        PhotoViewerRepresentable(image: image, onDismiss: { dismiss() })
            .ignoresSafeArea()
#else
        macOSBody
#endif
    }

#if os(macOS)
    @State private var loadedImage: PlatformImage?
    @State private var shareURL: URL?
    @State private var shareTaskID = UUID()
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero

    @ViewBuilder
    private var macOSBody: some View {
        ZStack(alignment: .top) {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            Group {
                switch image {
                case .local(let img):
                    zoomableImage(Image(platformImage: img))
                        .onAppear { setLoadedImage(img) }
                case .remote(let url):
                    CachedAsyncImage(url: url) { img in
                        zoomableImage(img)
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                    .task {
                        if let cached = ImageCache.shared.get(for: url) {
                            setLoadedImage(cached)
                        } else if let (data, _) = try? await URLSession.shared.data(from: url),
                                  let img = makePlatformImage(from: data) {
                            ImageCache.shared.set(img, for: url)
                            setLoadedImage(img)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: dragOffset.height)

            HStack(spacing: 20) {
                Spacer()
                if let img = loadedImage {
                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    } else {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .task(id: shareTaskID) {
                                shareURL = makeTemporaryShareURL(for: img)
                            }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .offset(y: dragOffset.height)
        }
        .simultaneousGesture(dismissDragGesture)
    }

    private func makeTemporaryShareURL(for image: PlatformImage) -> URL? {
        guard let data = platformJPEGData(from: image, compressionQuality: 0.9) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-image-\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        try? data.write(to: url, options: .atomic)
        return url
    }

    private func setLoadedImage(_ image: PlatformImage) {
        loadedImage = image
        shareURL = nil
        shareTaskID = UUID()
    }

    @ViewBuilder
    private func zoomableImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in scale = lastScale * value }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1 { withAnimation { scale = 1; lastScale = 1 } }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation { scale = scale > 1 ? 1 : 2.5; lastScale = scale }
            }
    }

    private var backgroundOpacity: Double {
        let distance = min(abs(dragOffset.height), 240)
        return max(0.35, 1.0 - (distance / 360))
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard scale <= 1.01 else { return }
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard scale <= 1.01 else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { dragOffset = .zero }
                    return
                }
                let shouldDismiss = abs(value.translation.height) > 120 || abs(value.predictedEndTranslation.height) > 180
                if shouldDismiss {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { dragOffset = .zero }
                }
            }
    }
#endif
}

// MARK: - iOS UIKit implementation

#if os(iOS)
private struct PhotoViewerRepresentable: UIViewControllerRepresentable {
    let image: ImageSource
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> PhotoViewerViewController {
        let vc = PhotoViewerViewController()
        vc.onDismiss = onDismiss
        return vc
    }

    func updateUIViewController(_ vc: PhotoViewerViewController, context: Context) {
        switch image {
        case .local(let img):
            vc.setImage(img)
        case .remote(let url):
            vc.loadImage(from: url)
        }
    }
}

final class PhotoViewerViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var shareButton: UIButton!
    private var loadingIndicator: UIActivityIndicatorView!

    var onDismiss: (() -> Void)?

    private var currentImage: UIImage?
    private var imageApplied = false
    private var pendingImage: UIImage?
    private var pendingURL: URL?
    private var urlLoadTask: Task<Void, Never>?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupShareButton()
        setupLoadingIndicator()
        setupGestures()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Make the SwiftUI fullScreenCover hosting container transparent
        // so the content behind shows through during drag-to-dismiss
        var current: UIViewController? = self
        while let p = current?.parent {
            p.view.backgroundColor = .clear
            current = p
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        if let pending = pendingImage {
            applyImage(pending)
            pendingImage = nil
        } else if imageApplied {
            adjustZoomBoundsAfterLayout()
            centerContent()
        }
    }

    // MARK: Setup

    private func setupScrollView() {
        view.backgroundColor = .black
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        scrollView.bouncesZoom = true
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
    }

    private func setupShareButton() {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "square.and.arrow.up",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        config.baseForegroundColor = .white
        config.background.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        shareButton = UIButton(configuration: config)
        shareButton.layer.cornerRadius = 22
        shareButton.clipsToBounds = true
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        view.addSubview(shareButton)

        NSLayoutConstraint.activate([
            shareButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            shareButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    // MARK: Public interface

    func setImage(_ image: UIImage) {
        guard currentImage !== image else { return }
        urlLoadTask?.cancel()
        urlLoadTask = nil
        pendingURL = nil
        currentImage = image
        if view.bounds.isEmpty {
            pendingImage = image
        } else {
            applyImage(image)
        }
    }

    func loadImage(from url: URL) {
        guard pendingURL != url else { return }
        urlLoadTask?.cancel()
        pendingURL = url

        if let cached = ImageCache.shared.get(for: url) {
            setImage(cached)
            return
        }

        loadingIndicator.startAnimating()
        shareButton.isHidden = true

        urlLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                if let image = UIImage(data: data) {
                    ImageCache.shared.set(image, for: url)
                    await MainActor.run {
                        self.loadingIndicator.stopAnimating()
                        self.shareButton.isHidden = false
                        self.setImage(image)
                    }
                }
            } catch {
                await MainActor.run { self.loadingIndicator.stopAnimating() }
            }
        }
    }

    // MARK: Private helpers

    private func applyImage(_ image: UIImage) {
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
        imageApplied = true
        updateZoomScales()
        centerContent()
    }

    private func updateZoomScales() {
        guard let image = imageView.image, view.bounds.width > 0 else { return }
        let scaleW = view.bounds.width / image.size.width
        let scaleH = view.bounds.height / image.size.height
        let minScale = min(scaleW, scaleH)
        let maxScale = max(minScale * 5, 3)

        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = maxScale
        scrollView.zoomScale = minScale
    }

    // Called on re-layout (rotation etc.) — updates zoom bounds without resetting the user's zoom level.
    private func adjustZoomBoundsAfterLayout() {
        guard let image = imageView.image, view.bounds.width > 0 else { return }
        let scaleW = view.bounds.width / image.size.width
        let scaleH = view.bounds.height / image.size.height
        let minScale = min(scaleW, scaleH)
        let maxScale = max(minScale * 5, 3)

        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = maxScale
        scrollView.zoomScale = max(minScale, min(scrollView.zoomScale, maxScale))
    }

    private func centerContent() {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    // MARK: Gestures

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let zoomScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 3)
            let w = scrollView.bounds.width / zoomScale
            let h = scrollView.bounds.height / zoomScale
            let rect = CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h)
            scrollView.zoom(to: rect, animated: true)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .changed:
            view.transform = CGAffineTransform(translationX: 0, y: translation.y)
            let alpha = max(0, 1 - abs(translation.y) / 300)
            view.backgroundColor = UIColor.black.withAlphaComponent(alpha)
            shareButton.alpha = max(0, 1 - abs(translation.y) / 80)
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view)
            let shouldDismiss = translation.y > 100 || velocity.y > 500
            if shouldDismiss {
                onDismiss?()
            } else {
                UIView.animate(withDuration: 0.3, delay: 0,
                               usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
                    self.view.transform = .identity
                    self.view.backgroundColor = .black
                    self.shareButton.alpha = 1
                }
            }
        default:
            break
        }
    }

    @objc private func shareTapped() {
        guard let image = currentImage else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activityVC, animated: true)
    }
}

extension PhotoViewerViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent() }
}

extension PhotoViewerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.001 else { return false }
        let vel = pan.velocity(in: view)
        return vel.y > 0 && abs(vel.y) > abs(vel.x)
    }
}
#endif
