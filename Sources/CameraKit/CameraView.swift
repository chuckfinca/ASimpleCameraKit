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
    
    /// Size of the capture button
    var captureButtonSize: CGFloat
    
    /// Size of the orientation guide
    var orientationGuideSize: CGFloat
    
    /// View model for camera logic
    @StateObject private var viewModel = CameraViewModel()
    
    /// Orientation manager for tracking device orientation
    @StateObject private var orientationManager = OrientationManager()
    
    // MARK: - Initialization
    
    /// Creates a new camera view
    /// - Parameters:
    ///   - onImageCaptured: Callback when an image is captured
    ///   - onError: Optional callback when an error occurs
    ///   - captureButtonSize: Size of the capture button (default: 70)
    ///   - orientationGuideSize: Size of the orientation guide (default: 50)
    ///   - overlayContent: Optional overlay content
    public init(
        onImageCaptured: @escaping (UIImage) -> Void,
        onError: ((Error) -> Void)? = nil,
        captureButtonSize: CGFloat = 70,
        orientationGuideSize: CGFloat = 50,
        overlayContent: (() -> Content)? = nil
    ) {
        self.onImageCaptured = onImageCaptured
        self.onError = onError
        self.captureButtonSize = captureButtonSize
        self.orientationGuideSize = orientationGuideSize
        self.overlayContent = overlayContent
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Camera preview - NOT wrapped in any rotation modifier
                if viewModel.isSessionRunning {
                    ZStack {
                        CameraPreview(session: viewModel.captureSession)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                }
                
                // UI Overlay - only the overlay elements adapt to orientation
                cameraUIOverlay(geometry: geometry)
                    .id(UIDevice.current.orientation) // Force refresh on orientation change
                
                // Custom overlay if provided
                if let overlayContent = overlayContent {
                    overlayContent()
                }
                
                // Loading overlay
                if viewModel.isCapturing {
                    LoadingOverlay(message: "Capturing...")
                }
            }
        }
        .task {
            print("CameraView - task started")
            await setupCamera()
        }
        .onAppear {
            print("CameraView - onAppear called")
            viewModel.onError = onError
            
            // Share the orientation manager with the view model
            viewModel.setOrientationManager(orientationManager)
        }
        .onDisappear {
            print("CameraView - onDisappear called")
            // Use Task to call the async method
            Task {
                await viewModel.stopSession()
            }
        }
        .errorAlert(
            isPresented: $viewModel.showError,
            error: viewModel.currentError,
            retryAction: {
                print("CameraView - Retrying camera setup")
                Task {
                    await setupCamera()
                }
            }
        )
        // Observe capturedImage updates
        .onChange(of: viewModel.capturedImage) { newImage in
            if let image = newImage {
                // Normalize the image
                if let normalizedImage = ImageOrientationService.shared.normalizeImage(image) {
                    onImageCaptured(normalizedImage)
                } else {
                    // Fallback to original if normalization fails
                    onImageCaptured(image)
                }
                
                // Clear the captured image to prepare for the next capture
                viewModel.capturedImage = nil
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupCamera() async {
        print("CameraView - Setting up camera")
        let authorized = await viewModel.checkPermissions()
        print("CameraView - Camera permissions authorized: \(authorized)")
        
        if authorized {
            do {
                // Step 1: Setup capture session
                try await viewModel.setupCaptureSession()
                
                // Step 2: Start session - simplified to a single async call
                print("Starting camera session")
                await viewModel.startSession()
                print("Camera session started")
            } catch {
                viewModel.currentError = error
                viewModel.showError = true
                onError?(error)
            }
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func cameraUIOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            // Orientation guide at the top
            VStack {
                OrientationGuideView.ceilingIndicator(
                    orientationManager: orientationManager,
                    size: orientationGuideSize
                )
                .padding(.top, 50)
                
                Spacer()
            }
            
            // Capture button - positioned based on orientation
            captureButtonPosition
        }
    }
    
    @ViewBuilder
    private var captureButtonPosition: some View {
        // Position the capture button based on current orientation
        Group {
            if UIDevice.current.orientation.isLandscape {
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        CaptureButton(
                            action: {
                                Task {
                                    await viewModel.capturePhoto()
                                }
                            },
                            disabled: viewModel.isCapturing,
                            size: captureButtonSize
                        )
                        Spacer()
                    }
                    .padding(.trailing, 30)
                }
            } else {
                VStack {
                    Spacer()
                    CaptureButton(
                        action: {
                            Task {
                                await viewModel.capturePhoto()
                            }
                        },
                        disabled: viewModel.isCapturing,
                        size: captureButtonSize
                    )
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

/// Special initializer for cases where no overlay is needed
public extension CameraView where Content == EmptyView {
    init(
        onImageCaptured: @escaping (UIImage) -> Void,
        onError: ((Error) -> Void)? = nil,
        captureButtonSize: CGFloat = 70,
        orientationGuideSize: CGFloat = 50
    ) {
        self.init(
            onImageCaptured: onImageCaptured,
            onError: onError,
            captureButtonSize: captureButtonSize,
            orientationGuideSize: orientationGuideSize,
            overlayContent: nil
        )
    }
}