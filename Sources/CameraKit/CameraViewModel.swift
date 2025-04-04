import SwiftUI
import Combine
import AVFoundation

/// View model that coordinates camera operations and state
class CameraViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether the capture session is running
    @Published var isSessionRunning = false
    
    /// Current device orientation
    @Published var orientation: UIDeviceOrientation = .portrait
    
    /// Whether the camera is currently capturing
    @Published var isCapturing = false
    
    /// Error information
    @Published var showError = false
    @Published var currentError: Error?
    
    /// The last captured image
    @Published var capturedImage: UIImage?
    
    // MARK: - Service Dependencies
    
    /// The underlying camera service
    private let cameraService: CameraServiceProtocol
    
    /// Orientation manager (can be injected)
    private var orientationManager: OrientationManager?
    
    /// Set of cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Pass-through Properties
    
    /// The active capture session (pass-through to service)
    var captureSession: AVCaptureSession {
        cameraService.captureSession
    }
    
    // Add a callback property
    var onError: ((Error) -> Void)?
    
    // MARK: - Initialization
    
    init(cameraService: CameraServiceProtocol = CameraService()) {
        self.cameraService = cameraService
        setupBindings()
    }
    
    // MARK: - Orientation Management
    
    /// Sets the orientation manager to use
    /// - Parameter manager: The orientation manager
    func setOrientationManager(_ manager: OrientationManager) {
        self.orientationManager = manager
        
        // Subscribe to orientation changes
        manager.$currentOrientation
            .receive(on: RunLoop.main)
            .sink { [weak self] newOrientation in
                self?.orientation = newOrientation
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind to isSessionRunning to update our @Published property
        cameraService.isSessionRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] running in
                print("CameraViewModel - Session running changed to \(running)")
                self?.isSessionRunning = running
            }
            .store(in: &cancellables)
        
        // Bind to deviceOrientation to update our local orientation property
        cameraService.deviceOrientation
            .receive(on: RunLoop.main)
            .sink { [weak self] newOrientation in
                print("CameraViewModel - Orientation changed to: \(newOrientation.rawValue)")
                self?.orientation = newOrientation
            }
            .store(in: &cancellables)
        
        // Bind to error updates
        cameraService.error
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)
        
        // Bind to captured images
        cameraService.capturedImage
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] image in
                self?.capturedImage = image
                self?.isCapturing = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods (Pass-through to service)
    
    /// Check camera permissions
    /// - Returns: Whether camera access is authorized
    func checkPermissions() async -> Bool {
        return await cameraService.checkPermissions()
    }
    
    /// Set up the camera capture session
    func setupCaptureSession() async throws {
        try await cameraService.setupCaptureSession()
    }
    
    /// Start the camera session
    func startSession() async {
        print("CameraViewModel - Starting session")
        await cameraService.startSession()
    }
    
    /// Stop the camera session
    func stopSession() async {
        print("CameraViewModel - Stopping session")
        await cameraService.stopSession()
    }
    
    /// Capture a photo
    func capturePhoto() async {
        print("CameraViewModel - Capturing photo")
        
        // Set state first on main thread
        await MainActor.run {
            isCapturing = true
        }
        
        do {
            try await cameraService.capturePhoto()
            // Note: isCapturing will be set to false in the capturedImage publisher callback
        } catch {
            await MainActor.run {
                isCapturing = false
                handleError(error)
            }
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        currentError = error
        showError = true
        print("CameraViewModel - Error: \(error.localizedDescription)")
        
        // Call the error handler if provided
        onError?(error)
    }
}