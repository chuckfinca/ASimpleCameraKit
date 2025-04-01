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
    
    /// View model for camera logic
    @StateObject private var viewModel = CameraViewModel()
    
    // MARK: - Initialization
    
    /// Creates a new camera view
    /// - Parameters:
    ///   - onImageCaptured: Callback when an image is captured
    ///   - onError: Optional callback when an error occurs
    ///   - showOrientationArrow: Whether to show the orientation arrow (default: true)
    ///   - captureButtonSize: Size of the capture button (default: 70)
    ///   - overlayContent: Optional overlay content
    public init(
        onImageCaptured: @escaping (UIImage) -> Void,
        onError: ((Error) -> Void)? = nil,
        showOrientationArrow: Bool = true,
        captureButtonSize: CGFloat = 70,
        overlayContent: (() -> Content)? = nil
    ) {
        self.onImageCaptured = onImageCaptured
        self.onError = onError
        self.showOrientationArrow = showOrientationArrow
        self.captureButtonSize = captureButtonSize
        self.overlayContent = overlayContent
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Camera preview - use viewModel.isSessionRunning
                if viewModel.isSessionRunning {
                    ZStack {
                        CameraPreview(session: viewModel.captureSession)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                }
                
                // UI Overlay
                cameraUIOverlay(geometry: geometry)
                
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
                onImageCaptured(image)
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
            // Orientation arrow (if enabled) - use viewModel.orientation
            if showOrientationArrow {
                OrientationArrow(orientation: viewModel.orientation)
            }
            
            // Capture button
            VStack {
                Spacer()
                
                CaptureButton(
                    action: {
                        // Use Task to call the async method
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

/// Special initializer for cases where no overlay is needed
public extension CameraView where Content == EmptyView {
    init(
        onImageCaptured: @escaping (UIImage) -> Void,
        onError: ((Error) -> Void)? = nil,
        showOrientationArrow: Bool = true,
        captureButtonSize: CGFloat = 70
    ) {
        self.init(
            onImageCaptured: onImageCaptured,
            onError: onError,
            showOrientationArrow: showOrientationArrow,
            captureButtonSize: captureButtonSize,
            overlayContent: nil
        )
    }
}