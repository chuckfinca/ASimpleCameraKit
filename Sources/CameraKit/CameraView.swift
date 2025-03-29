import SwiftUI
import Combine
import AVFoundation

/// A complete camera capture view that manages its own state
public struct CameraView<Content: View>: View {
    /// Callback when an image is captured
    var onImageCaptured: (UIImage) -> Void
    
    /// Callback when an error occurs
    var onError: ((Error) -> Void)?
    
    /// Optional overlay content
    var overlayContent: (() -> Content)?
    
    /// Whether to show the orientation arrow
    var showOrientationArrow: Bool
    
    /// Size of the capture button
    var captureButtonSize: CGFloat
    
    /// Whether to fix the preview orientation
    var fixedPreviewOrientation: Bool
    
    /// Camera service
    @StateObject private var cameraService = CameraService()
    
    /// View state
    @State private var orientation: UIDeviceOrientation = .portrait
    @State private var isCapturing = false
    @State private var showError = false
    @State private var currentError: Error?
    
    /// View model subscription
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a new camera view
    /// - Parameters:
    ///   - onImageCaptured: Callback when an image is captured
    ///   - onError: Optional callback when an error occurs
    ///   - showOrientationArrow: Whether to show the orientation arrow (default: true)
    ///   - captureButtonSize: Size of the capture button (default: 70)
    ///   - fixedPreviewOrientation: Whether to fix the preview orientation (default: false)
    ///   - overlayContent: Optional overlay content
    public init(
        onImageCaptured: @escaping (UIImage) -> Void,
        onError: ((Error) -> Void)? = nil,
        showOrientationArrow: Bool = true,
        captureButtonSize: CGFloat = 70,
        fixedPreviewOrientation: Bool = false,
        overlayContent: (() -> Content)? = nil
    ) {
        self.onImageCaptured = onImageCaptured
        self.onError = onError
        self.showOrientationArrow = showOrientationArrow
        self.captureButtonSize = captureButtonSize
        self.fixedPreviewOrientation = fixedPreviewOrientation
        self.overlayContent = overlayContent
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Camera preview - always full screen
                if cameraService.isSessionRunning.value {
                    CameraPreviewView(
                        session: cameraService.captureSession,
                        orientation: $orientation,
                        fixedOrientation: fixedPreviewOrientation
                    )
                    .edgesIgnoringSafeArea(.all)
                }
                
                // UI Overlay
                cameraUIOverlay(geometry: geometry)
                
                // Custom overlay if provided
                if let overlayContent = overlayContent {
                    overlayContent()
                }
                
                // Loading overlay
                if isCapturing {
                    LoadingOverlay(message: "Capturing...")
                }
            }
        }
        .task {
            await setupCamera()
        }
        .onAppear {
            setupSubscriptions()
        }
        .onDisappear {
            cameraService.stopSession()
            cancellables.removeAll()
        }
        .errorAlert(
            isPresented: $showError,
            error: currentError
        )
    }
    
    // MARK: - Setup
    
    private func setupCamera() async {
        let authorized = await cameraService.checkPermissions()
        
        if authorized {
            do {
                try await cameraService.setupCaptureSession()
                cameraService.startSession()
            } catch {
                handleError(error)
            }
        }
    }
    
    private func setupSubscriptions() {
        // Get initial orientation
        orientation = cameraService.deviceOrientation.value
        
        // Subscribe to orientation changes
        cameraService.deviceOrientation
            .receive(on: RunLoop.main)
            .sink { newOrientation in
                orientation = newOrientation
            }
            .store(in: &cancellables)
        
        // Subscribe to captured images
        cameraService.capturedImage
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { image in
                isCapturing = false
                onImageCaptured(image)
            }
            .store(in: &cancellables)
        
        // Subscribe to errors
        cameraService.error
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { error in
                handleError(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    private func capturePhoto() {
        isCapturing = true
        
        Task {
            do {
                try await cameraService.capturePhoto()
            } catch {
                await MainActor.run {
                    isCapturing = false
                    handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: Error) {
        currentError = error
        showError = true
        onError?(error)
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func cameraUIOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            // Orientation arrow (if enabled)
            if showOrientationArrow {
                OrientationArrow(orientation: orientation)
            }
            
            // Capture button
            VStack {
                Spacer()
                
                CaptureButton(
                    action: capturePhoto,
                    disabled: isCapturing,
                    size: captureButtonSize
                )
                .padding(.bottom, 30)
            }
        }
    }
}

/// Special initializer for cases where no overlay is needed
public extension CameraView where Content == EmptyView {
    init(
        onImageCaptured: @escaping (UIImage) -> Void,
        onError: ((Error) -> Void)? = nil,
        showOrientationArrow: Bool = true,
        captureButtonSize: CGFloat = 70,
        fixedPreviewOrientation: Bool = false
    ) {
        self.init(
            onImageCaptured: onImageCaptured,
            onError: onError,
            showOrientationArrow: showOrientationArrow,
            captureButtonSize: captureButtonSize,
            fixedPreviewOrientation: fixedPreviewOrientation,
            overlayContent: nil
        )
    }
}