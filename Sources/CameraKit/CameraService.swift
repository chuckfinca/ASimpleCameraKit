import AVFoundation
import UIKit
import Combine
import SwiftUI

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
            let currentOrientation = self.orientationManager.captureOrientation
            self.deviceOrientation.send(currentOrientation)

            // Set up photo settings
            let photoSettings = AVCapturePhotoSettings()


            // Ensure metadata is preserved including EXIF
            if #available(iOS 16.0, *) {
                // Modern way to specify high quality on iOS 16+
                // Optional: Set dimensions if you need specific size
                // photoSettings.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
            } else {
                // For iOS 15 and earlier, check if high resolution is supported
                if self.photoOutput.isHighResolutionCaptureEnabled {
                    photoSettings.isHighResolutionPhotoEnabled = true
                }
            }

            // Ensure photo quality prioritization is supported
            if #available(iOS 15.0, *) {
                let maxPrioritization = self.photoOutput.maxPhotoQualityPrioritization
                photoSettings.photoQualityPrioritization = maxPrioritization
            }

            // Add orientation data to EXIF metadata for more reliable orientation handling
            let orientationMetadata = [
                kCGImagePropertyOrientation: currentOrientation.cgImagePropertyOrientation.rawValue
            ]

            photoSettings.metadata = [
                kCGImagePropertyExifDictionary as String: orientationMetadata
            ] as [String: Any]

            print("CameraService - Capturing photo with orientation: \(currentOrientation.rawValue)")

            // Capture photo
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
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

extension UIDeviceOrientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .portrait:
            return .right // 6
        case .portraitUpsideDown:
            return .left // 8
        case .landscapeLeft:
            return .down // 3
        case .landscapeRight:
            return .up // 1
        case .faceUp, .faceDown, .unknown:
            return .right // Default to portrait (6)
        @unknown default:
            return .right
        }
    }
}
