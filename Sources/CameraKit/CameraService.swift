import AVFoundation
import UIKit
import Combine
import SwiftUI

/// Protocol defining the interface for a camera service
public protocol CameraServiceProtocol {
    /// The active capture session
    var captureSession: AVCaptureSession { get }
    
    /// Publisher for the most recently captured image
    var capturedImage: CurrentValueSubject<UIImage?, Never> { get }
    
    /// Publisher for the current device orientation
    var deviceOrientation: CurrentValueSubject<UIDeviceOrientation, Never> { get }
    
    /// Publisher for the session running state
    var isSessionRunning: CurrentValueSubject<Bool, Never> { get }
    
    /// Publisher for any errors that occur
    var error: CurrentValueSubject<Error?, Never> { get }
    
    /// Orientation manager for orientation tracking
    var orientationManager: OrientationManager { get }
    
    /// Checks camera permissions
    /// - Returns: Whether camera access is authorized
    func checkPermissions() async -> Bool
    
    /// Sets up the capture session
    /// - Throws: CameraError if setup fails
    func setupCaptureSession() async throws
    
    /// Starts the capture session
    func startSession() async
    
    /// Stops the capture session
    func stopSession() async
    
    /// Captures a photo
    /// - Throws: CameraError if capture fails
    func capturePhoto() async throws
    
    /// Captures a photo and automatically normalizes it
    /// - Returns: Normalized UIImage with orientation set to .up
    /// - Throws: CameraError if capture fails
    func captureNormalizedPhoto() async throws -> UIImage
    
    /// Returns the current device orientation
    /// - Returns: The current device orientation
    func getCurrentOrientation() -> UIDeviceOrientation
    
    /// Creates an overlay that shows orientation information
    /// - Parameters:
    ///   - size: Size of the orientation guide
    ///   - color: Color of the orientation guide
    /// - Returns: An orientation guide view
    func createOrientationGuide(size: CGFloat, color: Color) -> OrientationGuideView
}

/// A service that manages camera functionality
public class CameraService: NSObject, CameraServiceProtocol, ObservableObject {
    // MARK: - Published Properties
    
    public let captureSession = AVCaptureSession()
    public let capturedImage = CurrentValueSubject<UIImage?, Never>(nil)
    public let deviceOrientation = CurrentValueSubject<UIDeviceOrientation, Never>(.portrait)
    public let isSessionRunning = CurrentValueSubject<Bool, Never>(false)
    public let error = CurrentValueSubject<Error?, Never>(nil)
    
    // MARK: - Orientation Management
    
    /// Orientation manager for tracking device orientation
    public let orientationManager: OrientationManager
    
    // MARK: - Private Properties
    
    private let photoOutput = AVCapturePhotoOutput()
    private var continuations = [CheckedContinuation<Void, Error>]()
    private var imageNormalizer = ImageOrientationService.shared
    
    // MARK: - Initialization
    
    public override init() {
        // Initialize orientation manager
        self.orientationManager = OrientationManager()
        
        super.init()
        
        // Subscribe to orientation changes from the manager
        setupOrientationSubscription()
    }
    
    private func setupOrientationSubscription() {
        // Forward orientation updates from manager to the deviceOrientation subject
        orientationManager.$currentOrientation
            .sink { [weak self] newOrientation in
                self?.deviceOrientation.send(newOrientation)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Camera Permissions
    
    public func checkPermissions() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            error.send(CameraError.accessDenied)
            return false
        @unknown default:
            error.send(CameraError.unknownError)
            return false
        }
    }
    
    // MARK: - Session Setup
    
    public func setupCaptureSession() async throws {
        // Clear session if already configured
        if captureSession.isRunning {
            await stopSession()
        }
        
        if captureSession.inputs.isEmpty == false {
            captureSession.inputs.forEach { captureSession.removeInput($0) }
        }
        
        if captureSession.outputs.isEmpty == false {
            captureSession.outputs.forEach { captureSession.removeOutput($0) }
        }
        
        // Check and get the video device
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.cameraUnavailable
        }
        
        // Create video device input
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            // Configure autofocus if available
            if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                try videoDevice.lockForConfiguration()
                videoDevice.focusMode = .continuousAutoFocus
                videoDevice.unlockForConfiguration()
            }
            
            // Begin session configuration
            captureSession.beginConfiguration()
            
            // Add inputs and outputs
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                throw CameraError.cannotAddInput
            }
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            } else {
                throw CameraError.cannotAddOutput
            }
            
            captureSession.commitConfiguration()
            
        } catch {
            throw error
        }
    }
    
    // MARK: - Session Control
    
    public func startSession() async {
        guard !captureSession.isRunning else { 
            print("CameraService - Session already running")
            return 
        }
        
        print("CameraService - Starting session")
        
        // Use a single detached task to run on background thread and wait for completion
        await Task.detached(priority: .userInitiated) {
            self.captureSession.startRunning()
            
            await MainActor.run {
                print("CameraService - Session started, updating state")
                self.isSessionRunning.send(true)
            }
        }.value
    }
    
    public func stopSession() async {
        guard captureSession.isRunning else { return }
        
        print("CameraService - Stopping session")
        
        await Task.detached(priority: .userInitiated) {
            self.captureSession.stopRunning()
            
            await MainActor.run {
                self.isSessionRunning.send(false)
            }
        }.value
    }
    
    // MARK: - Photo Capture
    
    public func capturePhoto() async throws {
        return try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self = self else {
                continuation.resume(throwing: CameraError.unknownError)
                return
            }
            
            self.continuations.append(continuation)
            
            // Store current device orientation from the orientation manager
            self.deviceOrientation.send(self.orientationManager.captureOrientation)
            
            // Set up photo settings
            let photoSettings = AVCapturePhotoSettings()
            
            // Capture photo
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK: - Enhanced API Methods
    
    /// Captures a photo and automatically normalizes it
    /// - Returns: Normalized UIImage with orientation set to .up
    /// - Throws: CameraError if capture fails
    public func captureNormalizedPhoto() async throws -> UIImage {
        // Capture the photo first
        try await capturePhoto()
        
        // Wait for the captured image to be set
        guard let capturedImg = await withCheckedContinuation({ continuation in
            // Check if image already exists
            if let image = self.capturedImage.value {
                continuation.resume(returning: image)
                return
            }
            
            // Otherwise set up a one-time observer
            let cancellable = self.capturedImage
                .compactMap { $0 }
                .first()
                .sink { image in
                    continuation.resume(returning: image)
                }
            
            // Store the cancellable to prevent it from being deallocated
            self.cancellables.insert(cancellable)
        }) else {
            throw CameraError.photoCaptureFailed
        }
        
        // Normalize the image
        guard let normalizedImage = imageNormalizer.normalizeImage(capturedImg) else {
            throw CameraError.photoCaptureFailed
        }
        
        return normalizedImage
    }
    
    /// Returns the current device orientation
    /// - Returns: The current device orientation
    public func getCurrentOrientation() -> UIDeviceOrientation {
        return orientationManager.captureOrientation
    }
    
    /// Creates an overlay that shows orientation information
    /// - Parameters:
    ///   - size: Size of the orientation guide
    ///   - color: Color of the orientation guide
    /// - Returns: An orientation guide view
    public func createOrientationGuide(size: CGFloat = 50, color: Color = .white) -> OrientationGuideView {
        return OrientationGuideView.ceilingIndicator(
            orientationManager: orientationManager,
            size: size,
            color: color
        )
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Get the continuation to resume
        guard let continuation = continuations.first else { return }
        continuations.removeFirst()
        
        if let error = error {
            continuation.resume(throwing: error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            continuation.resume(throwing: CameraError.photoCaptureFailed)
            return
        }
        
        capturedImage.send(image)
        continuation.resume()
    }
}