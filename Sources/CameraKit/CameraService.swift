import AVFoundation
import UIKit
import Combine

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
    
    /// Checks camera permissions
    /// - Returns: Whether camera access is authorized
    func checkPermissions() async -> Bool
    
    /// Sets up the capture session
    /// - Throws: CameraError if setup fails
    func setupCaptureSession() async throws
    
    /// Starts the capture session
    func startSession()
    
    /// Stops the capture session
    func stopSession()
    
    /// Captures a photo
    /// - Throws: CameraError if capture fails
    func capturePhoto() async throws
}

/// A service that manages camera functionality
public class CameraService: NSObject, CameraServiceProtocol, ObservableObject {
    // MARK: - Published Properties
    
    public let captureSession = AVCaptureSession()
    public let capturedImage = CurrentValueSubject<UIImage?, Never>(nil)
    public let deviceOrientation = CurrentValueSubject<UIDeviceOrientation, Never>(.portrait)
    public let isSessionRunning = CurrentValueSubject<Bool, Never>(false)
    public let error = CurrentValueSubject<Error?, Never>(nil)
    
    // MARK: - Private Properties
    
    private let photoOutput = AVCapturePhotoOutput()
    private var continuations = [CheckedContinuation<Void, Error>]()
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        
        // Start monitoring device orientation
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Initialize with current orientation if valid, otherwise default to portrait
        let currentOrientation = UIDevice.current.orientation
        if currentOrientation.isPortrait || currentOrientation.isLandscape {
            self.deviceOrientation.send(currentOrientation)
        } else {
            self.deviceOrientation.send(.portrait)
        }
        
        // Set up orientation notification observation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Orientation Handling
    
    @objc private func orientationChanged() {
        let newOrientation = UIDevice.current.orientation
        print("CameraService - Orientation changed to: \(newOrientation.rawValue)")
            
        // Only update for valid orientations (not face up/down)
        if newOrientation != .faceUp && newOrientation != .faceDown && newOrientation != .unknown {
            DispatchQueue.main.async { [weak self] in
                self?.deviceOrientation.send(newOrientation)
            }
        }
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
            stopSession()
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
    
    public func startSession() {
        guard !captureSession.isRunning else { 
            print("CameraService - Session already running")
            return 
        }
        
        print("CameraService - Starting session")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning.send(true)
            }
        }
    }
    
    public func stopSession() {
        guard captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning.send(false)
            }
        }
    }
    
    // MARK: - Photo Capture
    
    public func capturePhoto() async throws {
        return try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self = self else {
                continuation.resume(throwing: CameraError.unknownError)
                return
            }
            
            self.continuations.append(continuation)
            
            // Store current device orientation
            self.deviceOrientation.send(UIDevice.current.orientation)
            
            // Set up photo settings
            let photoSettings = AVCapturePhotoSettings()
            
            // Capture photo
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
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